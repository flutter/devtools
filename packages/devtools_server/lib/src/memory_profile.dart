// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import 'service_registrations.dart' as registrations;

//import 'package:devtools_app/src/memory/flutter/memory_protocol.dart';
//import 'package:devtools_app/src/vm_service_wrapper.dart';

class MemoryProfile {
  MemoryProfile(this.service, String profileFilename) {
    onConnectionClosed.listen(_handleConnectionStop);

    service.onEvent('Service').listen(handleServiceEvent);

    _jsonFile = JsonFile.create(profileFilename);

    hookUpEvents();

    start();
  }

  JsonFile _jsonFile;

  void hookUpEvents() async {
    final streamIds = [
      EventStreams.kExtension,
      EventStreams.kGC,
      EventStreams.kIsolate,
      // TODO(terry): probably should save logs, stderr to JSON too?
      EventStreams.kLogging,
      EventStreams.kStderr,
      // TODO(terry): maybe with a switch save logs too (for debugging)?
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

    final time = DateTime.now().millisecondsSinceEpoch;
    final sample = HeapSample(
      time,
      processRss,
      capacity,
      used,
      external,
      fromGC,
      adbMemoryInfo,
    );

    print(' sample: [$time] capacity=$capacity, adbMemoryInfo nativeHeap=${adbMemoryInfo.nativeHeap}');

    _jsonFile.writeSample(sample);
  }

  // TODO(devoncarew): fix HeapSpace.parse upstream
  static Iterable<HeapSpace> getHeaps(Isolate isolate) {
    final Map<String, dynamic> heaps = isolate.json['_heaps'];
    return heaps.values.map((dynamic json) => HeapSpace.parse(json));
  }
}

class JsonFile {
  JsonFile.create(this._absoluteFileName) {
    _open();
  }

  final String _absoluteFileName;
  io.File _fs;
  io.RandomAccessFile _raFile;
  bool _multipleSamples = false;

  void _open() async {
    _fs = io.File(_absoluteFileName);
    _raFile = _fs.openSync(mode: io.FileMode.writeOnly);

    await _populateJsonHeader();
  }

  Future<void> _populateJsonHeader() async {
    assert(_raFile != null);
    final payload = '$memoryJsonHeader$memoryJsonTrailer';
    await _raFile.writeString(payload);
    await _raFile.flush();
  }

  Future<void> _setPositionToWriteSample() async {
    // Set the file position to the data array field contents - inside of [].
    final filePosition = await _raFile.position();
    await _raFile.setPosition(filePosition - memoryJsonTrailer.length);
  }

  void writeSample(HeapSample sample) async {
    await _setPositionToWriteSample();

    String encodedSample;
    if (_multipleSamples) {
      encodedSample = memoryEncodeAnotherHeapSample(sample);
    } else {
      encodedSample = memoryEncodeHeapSample(sample);
    }

    await _raFile.writeString('$encodedSample$memoryJsonTrailer');

    await _raFile.flush();

    _multipleSamples = true;
  }
}
