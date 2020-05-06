// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import '../../config_specific/logger/logger.dart';
import '../../globals.dart';
import '../../version.dart';
import '../../vm_service_wrapper.dart';
import 'memory_controller.dart';

class MemoryTracker {
  MemoryTracker(this.service, this.memoryController);

  static const Duration _updateDelay = Duration(milliseconds: 1000);

  VmServiceWrapper service;

  final MemoryController memoryController;

  Timer _pollingTimer;

  final List<HeapSample> samples = <HeapSample>[];
  final Map<String, List<HeapSpace>> isolateHeaps = <String, List<HeapSpace>>{};
  int heapMax;

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
    paused ??= memoryController.paused.value;

    if (paused) {
      _pollingTimer?.cancel();
      _gcStreamListener?.cancel();
    } else {
      _pollingTimer = Timer(Duration.zero, _pollMemory);
      _gcStreamListener = service.onGCEvent.listen(_handleGCEvent);
    }
  }

  void stop() {
    _updateLiveDataPolling(false);
    memoryController.paused.removeListener(_updateLiveDataPolling);
    service = null;
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

  // TODO(terry): Discuss need a record/stop record for memory?  Unless expensive probably not.
  Future<void> _pollMemory() async {
    if (!hasConnection || memoryController.memoryTracker == null) {
      return;
    }

    final VM vm = await service.getVM();

    // TODO(terry): Need to handle a possible Sentinel being returned.
    final List<Isolate> isolates =
        await Future.wait(vm.isolates.map((IsolateRef ref) async {
      try {
        return await service.getIsolate(ref.id);
      } catch (e) {
        // TODO(terry): Seem to sometimes get a sentinel not sure how? VM issue?
        // Unhandled Exception: type 'Sentinel' is not a subtype of type 'FutureOr<Isolate>'
        log('Error [MEMORY_PROTOCOL]: $e');
        return null;
      }
    }));

    // Polls for current Android meminfo using:
    //    > adb shell dumpsys meminfo -d <package_name>
    if (hasConnection && vm.operatingSystem == 'android') {
      adbMemoryInfo = await _fetchAdbInfo();
    } else {
      // TODO(terry): TBD alternative for iOS memory info - all values zero.
      adbMemoryInfo = AdbMemoryInfo.empty();
    }

    // Polls for current RSS size.
    _update(vm, isolates);
    _pollingTimer = Timer(_updateDelay, _pollMemory);
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

  // Poll ADB meminfo
  Future<AdbMemoryInfo> _fetchAdbInfo() async =>
      AdbMemoryInfo.fromJson((await serviceManager.getAdbMemoryInfo()).json);

  void _recalculate([bool fromGC = false]) async {
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

    int time = DateTime.now().millisecondsSinceEpoch;
    if (samples.isNotEmpty) {
      time = math.max(time, samples.last.timestamp);
    }

    _addSample(HeapSample(
      time,
      processRss,
      capacity,
      used,
      external,
      fromGC,
      adbMemoryInfo,
    ));

    memoryController.memoryTimeline.addSample(HeapSample(
      time,
      processRss,
      capacity,
      used,
      external,
      fromGC,
      adbMemoryInfo,
    ));
  }

  void _addSample(HeapSample sample) {
    samples.add(sample);

    _changeController.add(null);
  }

  // TODO(devoncarew): fix HeapSpace.parse upstream
  static Iterable<HeapSpace> getHeaps(Isolate isolate) {
    if (isolate != null) {
      final Map<String, dynamic> heaps = isolate.json['_heaps'];
      return heaps.values.map((dynamic json) => HeapSpace.parse(json));
    }

    return const Iterable.empty();
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
