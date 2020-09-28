// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:intl/intl.dart' as intl;
import 'package:vm_service/vm_service.dart';

import 'service_registrations.dart' as registrations;

class MemoryProfile {
  MemoryProfile(this.service, String profileFilename, this._verboseMode) {
    onConnectionClosed.listen(_handleConnectionStop);

    service.onEvent('Service').listen(handleServiceEvent);

    _jsonFile = MemoryJsonFile.create(profileFilename);

    _hookUpEvents();
  }

  MemoryJsonFile _jsonFile;

  final bool _verboseMode;

  void _hookUpEvents() async {
    final streamIds = [
      EventStreams.kExtension,
      EventStreams.kGC,
      EventStreams.kIsolate,
      EventStreams.kLogging,
      EventStreams.kStderr,
      EventStreams.kStdout,
      // TODO(Kenzi): Collect timeline data too.
      // EventStreams.kTimeline,
      EventStreams.kVM,
      EventStreams.kService,
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

  static const Duration updateDelay = Duration(milliseconds: 500);

  VmService service;

  Timer _pollingTimer;

  /// Polled VM current RSS.
  int processRss;

  final Map<String, List<HeapSpace>> isolateHeaps = <String, List<HeapSpace>>{};

  final List<HeapSample> samples = <HeapSample>[];

  AdbMemoryInfo adbMemoryInfo;

  EventSample eventSample;

  RasterCache rasterCache;

  int heapMax;

  Stream<void> get onConnectionClosed => _connectionClosedController.stream;
  final _connectionClosedController = StreamController<void>.broadcast();

  void _handleConnectionStop(dynamic event) {
    // TODO(terry): Gracefully handle connection loss.
  }

  // TODO(terry): Investigate moving code from this point through end of class to devtools_shared.
  void startPolling() {
    _pollingTimer = Timer(updateDelay, _pollMemory);
    service.onGCEvent.listen(_handleGCEvent);
  }

  void _handleGCEvent(Event event) {
    //final bool ignore = event.json['reason'] == 'compact';

    final List<HeapSpace> heaps = <HeapSpace>[
      HeapSpace.parse(event.json['new']),
      HeapSpace.parse(event.json['old'])
    ];
    _updateGCEvent(event.isolate.id, heaps);
    // TODO(terry): expose when GC occured as markers in memory timeline.
  }

  void stopPolling() {
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
    _selectedIsolate = IsolateRef(
      id: isolate.id,
      name: isolate.name,
      number: isolate.number,
      isSystemIsolate: isolate.isSystemIsolate,
    );

    if (hasConnection &&
        vm.operatingSystem == 'android' &&
        _selectedIsolate != null) {
      // Poll ADB meminfo
      adbMemoryInfo = await _fetchAdbInfo();
    } else {
      // TODO(terry): TBD alternative for iOS memory info - all values zero.
      adbMemoryInfo = AdbMemoryInfo.empty();
    }

    // Query the engine's rasterCache estimate.
    rasterCache = await _fetchRasterCacheInfo(_selectedIsolate);

    // TODO(terry): There are no user interactions.  However, might be nice to
    //              record VM GC's on the timeline.
    eventSample = EventSample.empty();

    // Polls for current RSS size.
    _update(vm, isolates);

    _pollingTimer = Timer(updateDelay, _pollMemory);
  }

  /// Poll ADB meminfo
  Future<AdbMemoryInfo> _fetchAdbInfo() async => AdbMemoryInfo.fromJsonInKB(
        (await getAdbMemoryInfo()).json,
      );

  /// Poll Fultter engine's Raster Cache metrics.
  /// @returns engine's rasterCache estimates or null.
  Future<RasterCache> _fetchRasterCacheInfo(IsolateRef selectedIsolate) async {
    final response = await getRasterCacheMetrics(selectedIsolate);
    if (response == null) return null;
    final rasterCache = RasterCache.parse(response.json);
    return rasterCache;
  }

  /// @returns view id of selected isolate's 'FlutterView'.
  /// @throws Exception if no 'FlutterView'.
  Future<String> getFlutterViewId(IsolateRef selectedIsolate) async {
    final flutterViewListResponse = await callService(
      registrations.flutterListViews,
      isolateId: selectedIsolate.id,
    );
    final List<dynamic> views =
        flutterViewListResponse.json['views'].cast<Map<String, dynamic>>();

    // Each isolate should only have one FlutterView.
    final flutterView = views.firstWhere(
      (view) => view['type'] == 'FlutterView',
      orElse: () => null,
    );

    if (flutterView == null) {
      final message =
          'No Flutter Views to query: ${flutterViewListResponse.json}';
      print('ERROR: $message');
      throw Exception(message);
    }

    return flutterView['id'];
  }

  /// Flutter engine returns estimate how much memory is used by layer/picture raster
  /// cache entries in bytes.
  ///
  /// Call to returns JSON payload 'EstimateRasterCacheMemory' with two entries:
  ///   layerBytes - layer raster cache entries in bytes
  ///   pictureBytes - picture raster cache entries in bytes
  Future<Response> getRasterCacheMetrics(IsolateRef selectedIsolate) async {
    final viewId = await getFlutterViewId(selectedIsolate);

    return await callService(
      registrations.flutterEngineRasterCache,
      args: <String, String>{
        'viewId': viewId,
      },
      isolateId: selectedIsolate.id,
    );
  }

  void _update(VM vm, List<Isolate> isolates) {
    processRss = vm.json['_currentRSS'];

    isolateHeaps.clear();

    for (Isolate isolate in isolates) {
      if (isolate != null) {
        final List<HeapSpace> heaps = getHeaps(isolate).toList();
        isolateHeaps[isolate.id] = heaps;
      }
    }

    _recalculate();
  }

  void _updateGCEvent(String id, List<HeapSpace> heaps) {
    isolateHeaps[id] = heaps;
    _recalculate(true);
  }

  void _recalculate([bool fromGC = false]) {
    int total = 0;

    int used = 0;
    int capacity = 0;
    int external = 0;
    for (List<HeapSpace> heaps in isolateHeaps.values) {
      used += heaps.fold<int>(0, (i, heap) => i + heap.used);
      capacity += heaps.fold<int>(0, (i, heap) => i + heap.capacity);
      external += heaps.fold<int>(0, (i, heap) => i + heap.external);

      capacity += external;

      total +=
          heaps.fold<int>(0, (i, heap) => i + heap.capacity + heap.external);
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
      eventSample,
      rasterCache,
    );

    if (_verboseMode) {
      final intl.DateFormat mFormat = intl.DateFormat('hh:mm:ss.mmm');
      final timeCollected =
          mFormat.format(DateTime.fromMillisecondsSinceEpoch(time));

      print(' Collected Sample: [$timeCollected] capacity=$capacity, '
          'ADB MemoryInfo total=${adbMemoryInfo.total}${fromGC ? ' [GC]' : ''}');
    }

    _jsonFile.writeSample(sample);
  }

  static Iterable<HeapSpace> getHeaps(Isolate isolate) {
    if (isolate != null) {
      final Map<String, dynamic> heaps = isolate.json['_heaps'];
      return heaps.values.map((dynamic json) => HeapSpace.parse(json));
    }
    return const Iterable.empty();
  }
}

class MemoryJsonFile {
  MemoryJsonFile.create(this._absoluteFileName) {
    _open();
  }

  final String _absoluteFileName;
  io.File _fs;
  io.RandomAccessFile _raFile;
  bool _multipleSamples = false;

  void _open() {
    _fs = io.File(_absoluteFileName);
    _raFile = _fs.openSync(mode: io.FileMode.writeOnly);

    _populateJsonHeader();
  }

  void _populateJsonHeader() {
    assert(_raFile != null);
    final payload = '${MemoryJson.header}${MemoryJson.trailer}';
    _raFile.writeStringSync(payload);
    _raFile.flushSync();
  }

  void _setPositionToWriteSample() {
    // Set the file position to the data array field contents - inside of [].
    final filePosition = _raFile.positionSync();
    _raFile.setPositionSync(filePosition - MemoryJson.trailer.length);
  }

  void writeSample(HeapSample sample) {
    _setPositionToWriteSample();

    String encodedSample;
    if (_multipleSamples) {
      encodedSample = MemoryJson.encodeAnotherHeapSample(sample);
    } else {
      encodedSample = MemoryJson.encodeHeapSample(sample);
    }

    _raFile.writeStringSync('$encodedSample${MemoryJson.trailer}');

    _raFile.flushSync();

    _multipleSamples = true;
  }
}
