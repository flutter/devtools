// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart' as logger;
import '../globals.dart';
import '../service_manager.dart';
import '../version.dart';
import '../vm_service_wrapper.dart';
import 'memory_controller.dart';

class MemoryTracker {
  MemoryTracker(this.serviceManager, this.memoryController);

  static const Duration _updateDelay = Duration(milliseconds: 500);

  ServiceConnectionManager serviceManager;

  final MemoryController memoryController;

  VmServiceWrapper get service => serviceManager?.service;

  Timer _pollingTimer;

  final List<HeapSample> samples = <HeapSample>[];
  final Map<String, MemoryUsage> isolateHeaps = <String, MemoryUsage>{};

  /// Polled VM current RSS.
  int processRss;

  /// Polled adb dumpsys meminfo values.
  AdbMemoryInfo adbMemoryInfo;

  bool get hasConnection => service != null;

  Stream<void> get onChange => _changeController.stream;
  final _changeController = StreamController<void>.broadcast();

  int get currentCapacity => samples.last.capacity;

  int get currentUsed => samples.last.used;

  int get currentExternal => samples.last.external;

  StreamSubscription<Event> _gcStreamListener;

  void start() {
    _updateLiveDataPolling(memoryController.paused.value);
    memoryController.paused.addListener(_updateLiveDataPolling);
  }

  void _updateLiveDataPolling([bool paused]) {
    if (service == null) {
      // A service of null implies we're disconnected - signal paused.
      memoryController.pauseLiveFeed();
    }
    paused ??= memoryController.paused.value;

    if (paused) {
      _pollingTimer?.cancel();
      _gcStreamListener?.cancel();
    } else {
      _pollingTimer = Timer(Duration.zero, _pollMemory);
      _gcStreamListener = service?.onGCEvent?.listen(_handleGCEvent);
    }
  }

  void stop() {
    _updateLiveDataPolling(false);
    memoryController.paused.removeListener(_updateLiveDataPolling);
    serviceManager = null;
  }

  void _handleGCEvent(Event event) {
    final HeapSpace newHeap = HeapSpace.parse(event.json['new']);
    final HeapSpace oldHeap = HeapSpace.parse(event.json['old']);

    final MemoryUsage memoryUsage = MemoryUsage(
      externalUsage: newHeap.external + oldHeap.external,
      heapCapacity: newHeap.capacity + oldHeap.capacity,
      heapUsage: newHeap.used + oldHeap.used,
    );

    _updateGCEvent(event.isolate.id, memoryUsage);
    // TODO(terry): expose when GC occured as markers in memory timeline.
  }

  // TODO(terry): Discuss need a record/stop record for memory?  Unless expensive probably not.
  Future<void> _pollMemory() async {
    if (!hasConnection || memoryController.memoryTracker == null) {
      return;
    }

    final isolateMemory = <IsolateRef, MemoryUsage>{};
    for (IsolateRef isolateRef in serviceManager.isolateManager.isolates) {
      try {
        await service.getIsolate(isolateRef.id);
      } catch (e) {
        if (e is SentinelException) {
          final SentinelException sentinelErr = e;
          logger.log('Isolate sentinel ${isolateRef.id} '
              '${sentinelErr.sentinel.kind}');
          continue;
        }
      }
      isolateMemory[isolateRef] = await service.getMemoryUsage(isolateRef.id);
    }

    // Polls for current Android meminfo using:
    //    > adb shell dumpsys meminfo -d <package_name>
    if (hasConnection && serviceManager.vm.operatingSystem == 'android') {
      adbMemoryInfo = await _fetchAdbInfo();
    } else {
      // TODO(terry): TBD alternative for iOS memory info - all values zero.
      adbMemoryInfo = AdbMemoryInfo.empty();
    }

    // Polls for current RSS size.
    _update(await service.getVM(), isolateMemory);

    _pollingTimer = Timer(_updateDelay, _pollMemory);
  }

  void _update(VM vm, Map<IsolateRef, MemoryUsage> isolateMemory) {
    processRss = vm.json['_currentRSS'];

    isolateHeaps.clear();

    for (IsolateRef isolateRef in isolateMemory.keys) {
      isolateHeaps[isolateRef.id] = isolateMemory[isolateRef];
    }

    _recalculate();
  }

  void _updateGCEvent(String isolateId, MemoryUsage memoryUsage) {
    isolateHeaps[isolateId] = memoryUsage;
    _recalculate(true);
  }

  // Poll ADB meminfo
  Future<AdbMemoryInfo> _fetchAdbInfo() async =>
      AdbMemoryInfo.fromJson((await serviceManager.getAdbMemoryInfo()).json);

  void _recalculate([bool fromGC = false]) async {
    int used = 0;
    int capacity = 0;
    int external = 0;

    for (MemoryUsage memoryUsage in isolateHeaps.values) {
      used += memoryUsage.heapUsage;
      capacity += memoryUsage.heapCapacity;
      external += memoryUsage.externalUsage;
    }

    int time = DateTime.now().millisecondsSinceEpoch;
    if (samples.isNotEmpty) {
      time = math.max(time, samples.last.timestamp);
    }

    final HeapSample sample = HeapSample(
      time,
      processRss,
      capacity + external,
      used,
      external,
      fromGC,
      adbMemoryInfo,
    );

    _addSample(sample);
    memoryController.memoryTimeline.addSample(sample);
  }

  void _addSample(HeapSample sample) {
    samples.add(sample);

    _changeController.add(null);
  }
}

// Heap Statistics

// Wrapper for ClassHeapStats.
//
// Pre VM Service Protocol 3.18:
// {
//   type: ClassHeapStats,
//   class: {type: @Class, fixedId: true, id: classes/5, name: Class},
//   new: [0, 0, 0, 0, 0, 0, 0, 0],
//   old: [3892, 809536, 3892, 809536, 0, 0, 0, 0],
//   promotedInstances: 0,
//   promotedBytes: 0
// }
//
// VM Service Protocol 3.18 and later:
// {
//   type: ClassHeapStats,
//   class: {type: @Class, fixedId: true, id: classes/5, name: Class},
//   accumulatedSize: 809536
//   bytesCurrent: 809536
//   instancesAccumulated: 3892
//   instancesCurrent: 3892
// }
class ClassHeapDetailStats {
  ClassHeapDetailStats(this.json) {
    classRef = ClassRef.parse(json['class']);
    if (serviceManager.service.protocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 18))) {
      instancesCurrent = json['instancesCurrent'];
      instancesAccumulated = json['instancesAccumulated'];
      bytesCurrent = json['bytesCurrent'];
      bytesAccumulated = json['bytesAccumulated'];
    } else {
      _update(json['new']);
      _update(json['old']);
    }
  }

  static const int ALLOCATED_BEFORE_GC = 0;
  static const int ALLOCATED_BEFORE_GC_SIZE = 1;
  static const int LIVE_AFTER_GC = 2;
  static const int LIVE_AFTER_GC_SIZE = 3;
  static const int ALLOCATED_SINCE_GC = 4;
  static const int ALLOCATED_SINCE_GC_SIZE = 5;
  static const int ACCUMULATED = 6;
  static const int ACCUMULATED_SIZE = 7;

  final Map<String, dynamic> json;

  int instancesCurrent = 0;
  int instancesAccumulated = 0;
  int bytesCurrent = 0;
  int bytesAccumulated = 0;

  ClassRef classRef;

  String get type => json['type'];

  void _update(List<dynamic> stats) {
    instancesAccumulated += stats[ACCUMULATED];
    bytesAccumulated += stats[ACCUMULATED_SIZE];
    instancesCurrent += stats[LIVE_AFTER_GC] + stats[ALLOCATED_SINCE_GC];
    bytesCurrent += stats[LIVE_AFTER_GC_SIZE] + stats[ALLOCATED_SINCE_GC_SIZE];
  }

  @override
  String toString() => '[ClassHeapStats type: $type, class: ${classRef.name}, '
      'count: $instancesCurrent, bytes: $bytesCurrent]';
}

class InstanceSummary {
  InstanceSummary(this.classRef, this.className, this.objectRef);

  final String classRef;
  final String className;
  final String objectRef;

  @override
  String toString() => '[InstanceSummary id: $objectRef, class: $classRef]';
}

class InstanceData {
  InstanceData(this.instance, this.name, this.value);

  final InstanceSummary instance;
  final String name;
  final dynamic value;

  @override
  String toString() => '[InstanceData name: $name, value: $value]';
}
