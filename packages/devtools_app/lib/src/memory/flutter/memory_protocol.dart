// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:vm_service/vm_service.dart';

import '../../globals.dart';
import '../../version.dart';
import '../../vm_service_wrapper.dart';

import '../heap_space.dart';
import 'memory_controller.dart';

class MemoryTracker {
  MemoryTracker(this.service, this.memoryController);

  static const Duration kUpdateDelay = Duration(milliseconds: 200);

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
        print('Error [MEMORY_PROTOCOL]: $e');
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

  // Poll ADB meminfo
  Future<AdbMemoryInfo> _fetchAdbInfo() async =>
      AdbMemoryInfo.fromJson((await serviceManager.getAdbMemoryInfo()).json);

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

// TODO(terry): Need the iOS version of this data.
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
