// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:vm_service/vm_service.dart';

import 'heap_space.dart';
import 'service_registrations.dart' as registrations;

//import 'package:devtools_app/src/memory/flutter/memory_protocol.dart';
//import 'package:devtools_app/src/vm_service_wrapper.dart';

class ProfileCollection {
  ProfileCollection(this.service) {
    onConnectionClosed.listen(_handleConnectionStop);

    service.onEvent('Service').listen(handleServiceEvent);

    hookUp();

    start();
  }

  void hookUp() async {
    final streamIds = [
      EventStreams.kExtension,
      EventStreams.kGC,
      EventStreams.kIsolate,
      // TODO(terry): probably should save logs, stderr to JSON too?
      EventStreams.kLogging,
      EventStreams.kStderr,
      // TODO(terry): maybe with a swtich save logs too (for debugging)?
      EventStreams.kStdout,
      // TODO(Kenzi): Collect timeline data too.
      // EventStreams.kTimeline,
      EventStreams.kVM,
      'Service',
    ];

    await Future.wait(streamIds.map((String id) async {
      try {
        await service.streamListen(id);
      } catch (e) {
        if (id.endsWith('Logging')) {
          // Don't complain about '_Logging' or 'Logging' events (new VMs don't
          // have the private names, and older ones don't have the public ones).
        } else {
          print("Service client stream not supported: '$id'\n  $e");
        }
      }
    }));
  }

  bool get hasConnection => service != null;

  void handleServiceEvent(Event e) {
    if (e.kind == EventKind.kServiceRegistered) {
      final serviceName = e.service;
      _registeredMethodsForService
          .putIfAbsent(serviceName, () => [])
          .add(e.method);
    }

    if (e.kind == EventKind.kServiceUnregistered) {
      final serviceName = e.service;
      _registeredMethodsForService.remove(serviceName);
    }
  }

  IsolateRef _selectedIsolate;

  Future<Response> getAdbMemoryInfo() async {
    return await callService(
      registrations.flutterMemory.service,
      isolateId: _selectedIsolate.id,
    );
  }

  /// Call a service that is registered by exactly one client.
  Future<Response> callService(
    String name, {
    String isolateId,
    Map args,
  }) async {
    final registered = _registeredMethodsForService[name] ?? const [];
    if (registered.isEmpty) {
      throw Exception('There are no registered methods for service "$name"');
    }
    return service.callMethod(
      registered.first,
      isolateId: isolateId,
      args: args,
    );
  }

  Map<String, List<String>> get registeredMethodsForService =>
      _registeredMethodsForService;
  final Map<String, List<String>> _registeredMethodsForService = {};

  static const Duration kUpdateDelay = Duration(milliseconds: 200);

  VmService service;

  Timer _pollingTimer;

  /// Polled VM current RSS.
  int processRss;

  final Map<String, List<HeapSpace>> isolateHeaps = <String, List<HeapSpace>>{};

  final List<HeapSample> samples = <HeapSample>[];

  AdbMemoryInfo adbMemoryInfo;

  int heapMax;

  Stream<void> get onConnectionClosed => _connectionClosedController.stream;
  final _connectionClosedController = StreamController<void>.broadcast();

  void _handleConnectionStop(dynamic event) {
    // TODO(terry): connection stopped.
    print('>>>> Connection STOPPED <<<<<');
  }

  void start() async {
    _pollingTimer = Timer(const Duration(milliseconds: 500), _pollMemory);
    // TODO(terry): Record when GC occurred?
//    service.onGCEvent.listen(_handleGCEvent);
  }

  void stop() {
    _pollingTimer?.cancel();
    service = null;
  }

  Future<void> _pollMemory() async {
    final VM vm = await service.getVM();

    // TODO(terry): Need to handle a possible Sentinel being returned.
    final List<Isolate> isolates =
        await Future.wait(vm.isolates.map((IsolateRef ref) async {
      try {
        return await service.getIsolate(ref.id);
      } catch (e) {
        // TODO(terry): Seem to sometimes get a sentinel not sure how? VM issue?
        // Unhandled Exception: type 'Sentinel' is not a subtype of type 'FutureOr<Isolate>'
        print('Error [MEMORY_PROTOCOL]: $e');
        return null;
      }
    }));

    // Polls for current Android meminfo using:
    //    > adb shell dumpsys meminfo -d <package_name>
    final isolate = isolates[0];
    _selectedIsolate =
        IsolateRef(id: isolate.id, name: isolate.name, number: isolate.number);
    ;
    if (hasConnection &&
        vm.operatingSystem == 'android' &&
        _selectedIsolate != null) {
      // Poll ADB meminfo
      adbMemoryInfo = await _fetchAdbInfo();
    } else {
      // TODO(terry): TBD alternative for iOS memory info - all values zero.
      adbMemoryInfo = AdbMemoryInfo.empty();
    }

    // Polls for current RSS size.
    _update(vm, isolates);
    _pollingTimer = Timer(kUpdateDelay, _pollMemory);
  }

  Future<AdbMemoryInfo> _fetchAdbInfo() async =>
      AdbMemoryInfo.fromJson((await getAdbMemoryInfo()).json);

  void _update(VM vm, List<Isolate> isolates) {
    processRss = vm.json['_currentRSS'];

    isolateHeaps.clear();

    for (Isolate isolate in isolates) {
      final List<HeapSpace> heaps = getHeaps(isolate).toList();
      isolateHeaps[isolate.id] = heaps;
    }

    _recalculate();
  }

  void _recalculate([bool fromGC = false]) async {
    int total = 0;

    int used = 0;
    int capacity = 0;
    int external = 0;
    for (List<HeapSpace> heaps in isolateHeaps.values) {
      used += heaps.fold<int>(0, (int i, HeapSpace heap) => i + heap.used);
      capacity +=
          heaps.fold<int>(0, (int i, HeapSpace heap) => i + heap.capacity);
      external +=
          heaps.fold<int>(0, (int i, HeapSpace heap) => i + heap.external);

      capacity += external;

      total += heaps.fold<int>(
          0, (int i, HeapSpace heap) => i + heap.capacity + heap.external);
    }

    heapMax = total;

    int time = DateTime.now().millisecondsSinceEpoch;
    var bootDuration = const Duration();
    if (samples.isNotEmpty) {
      time = math.max(time, samples.last.timestamp);
      bootDuration = samples.last.adbMemoryInfo.bootDuration;
    }

    final sample = HeapSample(
      time,
      processRss,
      capacity,
      used,
      external,
      fromGC,
      adbMemoryInfo,
    );

    samples.add(sample);
  }

  void persistSamples() {
    bool pseudoData = false;
    if (samples.isEmpty) {
      // TODO(terry): Can eliminate once I add loading a canned data source
      //              see TODO in memory_screen_test.
      // Used to create empty memory log for test.
      pseudoData = true;
      samples.add(HeapSample(
        DateTime.now().microsecondsSinceEpoch,
        0,
        0,
        0,
        0,
        false,
        AdbMemoryInfo.empty(),
      ));
    }

    final jsonPayload = encodeHeapSamples(samples);

    _fs.writeStringToFile(_memoryLogFilename, jsonPayload);

    // TODO(terry): Display filename created in a toast.

    if (pseudoData) samples.clear();
  }

  // TODO(terry): Start of stuff to expose in a shared memory json package

  /// Version of timeline data (HeapSample) JSON payload.
  static const version = 1;

  static const String _jsonPayloadField = 'samples';
  static const String _jsonVersionField = 'version';
  static const String _jsonDataField = 'data';

  /// Given a list of HeapSample, encode as a Json string.
  static String encodeHeapSamples(List<HeapSample> data) {
    final result = StringBuffer();

    // Iterate over all HeapSamples collected.
    data.map((f) {
      if (result.isNotEmpty) result.write(',\n');
      final encode = jsonEncode(f);
      result.write('$encode');
    }).toList();

    return '{"$_jsonPayloadField": {'
        '"$_jsonVersionField": $version, "$_jsonDataField": [\n'
        '$result'
        '\n]\n}}';
  }
  // TODO(terry): end of stuff to expose in a shared memory json package.

  // TODO(devoncarew): fix HeapSpace.parse upstream
  static Iterable<HeapSpace> getHeaps(Isolate isolate) {
    final Map<String, dynamic> heaps = isolate.json['_heaps'];
    return heaps.values.map((dynamic json) => HeapSpace.parse(json));
  }
}

class HeapSample {
  HeapSample(
    this.timestamp,
    this.rss,
    this.capacity,
    this.used,
    this.external,
    this.isGC,
    this.adbMemoryInfo,
  );

  factory HeapSample.fromJson(Map<String, dynamic> json) => HeapSample(
        json['timestamp'] as int,
        json['rss'] as int,
        json['capacity'] as int,
        json['used'] as int,
        json['external'] as int,
        json['gc'] as bool,
        AdbMemoryInfo.fromJson(json['adb_memoryInfo']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp,
        'rss': rss,
        'capacity': capacity,
        'used': used,
        'external': external,
        'gc': isGC,
        'adb_memoryInfo': adbMemoryInfo.toJson(),
      };

  final int timestamp;

  final int rss;

  final int capacity;

  final int used;

  final int external;

  final bool isGC;

  final AdbMemoryInfo adbMemoryInfo;

  @override
  String toString() => '[HeapSample timestamp: $timestamp, rss: $rss, '
      'capacity: $capacity, used: $used, external: $external, '
      'isGC: $isGC, AdbMemoryInfo: $adbMemoryInfo]';
}

/// Android ADB dumpsys meminfo data.
class AdbMemoryInfo {
  AdbMemoryInfo(
    this.realtime,
    this.javaHeap,
    this.nativeHeap,
    this.code,
    this.stack,
    this.graphics,
    this.other,
    this.system,
    this.total,
  );

  factory AdbMemoryInfo.fromJson(Map<String, dynamic> json) => AdbMemoryInfo(
        json[realTimeKey] as int,
        json[javaHeapKey] as int,
        json[nativeHeapKey] as int,
        json[codeKey] as int,
        json[stackKey] as int,
        json[graphicsKey] as int,
        json[otherKey] as int,
        json[systemKey] as int,
        json[totalKey] as int,
      );

  /// JSON keys of data retrieved from ADB tool.
  static const String realTimeKey = 'Realtime';
  static const String javaHeapKey = 'Java Heap';
  static const String nativeHeapKey = 'Native Heap';
  static const String codeKey = 'Code';
  static const String stackKey = 'Stack';
  static const String graphicsKey = 'Graphics';
  static const String otherKey = 'Private Other';
  static const String systemKey = 'System';
  static const String totalKey = 'Total';

  Map<String, dynamic> toJson() => <String, dynamic>{
        realTimeKey: realtime,
        javaHeapKey: javaHeap,
        nativeHeapKey: nativeHeap,
        codeKey: code,
        stackKey: stack,
        graphicsKey: graphics,
        otherKey: other,
        systemKey: system,
        totalKey: total,
      };

  /// Create an empty AdbMemoryInfo (all values are)
  static AdbMemoryInfo empty() => AdbMemoryInfo(0, 0, 0, 0, 0, 0, 0, 0, 0);

  /// Milliseconds since the device was booted (value zero) including deep sleep.
  ///
  /// This clock is guaranteed to be monotonic, and continues to tick even
  /// in power saving mode. The value zero is Unix Epoch UTC (Jan 1, 1970 00:00:00).
  /// This DateTime, from USA PST, would be Dec 31, 1960 16:00:00 (UTC - 8 hours).
  final int realtime;

  final int javaHeap;

  final int nativeHeap;

  final int code;

  final int stack;

  final int graphics;

  final int other;

  final int system;

  final int total;

  DateTime get realtimeDT => DateTime.fromMillisecondsSinceEpoch(realtime);

  /// Duration the device has been up since boot time.
  Duration get bootDuration => Duration(milliseconds: realtime);

  @override
  String toString() => '[AdbMemoryInfo $realTimeKey: $realtime'
      ', realtimeDT: $realtimeDT, durationBoot: $bootDuration'
      ', $javaHeapKey: $javaHeap, $nativeHeapKey: $nativeHeap'
      ', $codeKey: $code, $stackKey: $stack, $graphicsKey: $graphics'
      ', $otherKey: $other, $systemKey: $system'
      ', $totalKey: $total]';
}

class JsonFile {
  JsonFile(this._absoluteFileName) {
    _open();
  }

  final String _absoluteFileName;

  io.File _fs;
  io.RandomAccessFile _raFile;

  void _open() async {
    _fs = io.File(_absoluteFileName);

    _raFile = await _fs.open(mode: io.FileMode.writeOnly);
  }

  void writeInitialJsonPayload() {
    if (_raFile != null) {
      _raFile.writeString(string);

      _raFile.po   
    }
  }

  void writeSample() {

  }

}