// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../vm_service_wrapper.dart';

class MemoryTracker {
  MemoryTracker(this.service);

  static const Duration kUpdateDelay = Duration(milliseconds: 200);

  VmServiceWrapper service;
  Timer _pollingTimer;
  final StreamController<Null> _changeController =
      StreamController<Null>.broadcast();

  final List<HeapSample> samples = <HeapSample>[];
  final Map<String, List<HeapSpace>> isolateHeaps = <String, List<HeapSpace>>{};
  int heapMax;
  int processRss;

  bool get hasConnection => service != null;

  Stream<Null> get onChange => _changeController.stream;

  int get currentCapacity => samples.last.capacity;

  int get currentUsed => samples.last.used;

  int get currentExternal => samples.last.external;

  void start() {
    _pollingTimer = Timer(const Duration(milliseconds: 500), _pollMemory);
    service.onGCEvent.listen(_handleGCEvent);
  }

  void stop() {
    _pollingTimer?.cancel();
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
  Future<Null> _pollMemory() async {
    if (!hasConnection) {
      return;
    }

    final VM vm = await service.getVM();
    // TODO(terry): Need to handle a possible Sentinel being returned.
    final List<Isolate> isolates =
        await Future.wait(vm.isolates.map((IsolateRef ref) async {
      return await service.getIsolate(ref.id);
    }));
    _update(vm, isolates);

    _pollingTimer = Timer(kUpdateDelay, _pollMemory);
  }

  void _update(VM vm, List<Isolate> isolates) {
    processRss = vm.json['_currentRSS'];

    isolateHeaps.clear();

    for (Isolate isolate in isolates) {
      final List<HeapSpace> heaps = getHeaps(isolate).toList();
      isolateHeaps[isolate.id] = heaps;
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
    if (samples.isNotEmpty) {
      time = math.max(time, samples.last.timestamp);
    }

    _addSample(HeapSample(time, processRss, capacity, used, external, fromGC));
  }

  void _addSample(HeapSample sample) {
    samples.add(sample);

    _changeController.add(null);
  }

  // TODO(devoncarew): fix HeapSpace.parse upstream
  static Iterable<HeapSpace> getHeaps(Isolate isolate) {
    final Map<String, dynamic> heaps = isolate.json['_heaps'];
    return heaps.values.map((dynamic json) => HeapSpace.parse(json));
  }
}

class HeapSample {
  HeapSample(this.timestamp, this.rss, this.capacity, this.used, this.external,
      this.isGC);

  final int timestamp;
  final int rss;
  final int capacity;
  final int used;
  final int external;
  final bool isGC;
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
    if (serviceManager.service.protocolVersionLessThan(major: 3, minor: 18)) {
      _update(json['new']);
      _update(json['old']);
    } else {
      instancesCurrent = json['instancesCurrent'];
      instancesAccumulated = json['instancesAccumulated'];
      bytesCurrent = json['bytesCurrent'];
      bytesAccumulated = json['bytesAccumulated'];
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
