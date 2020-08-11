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
import 'memory_timeline.dart';

class MemoryTracker {
  MemoryTracker(this.serviceManager, this.memoryController);

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

  Timer _monitorContinues;

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
      _gcStreamListener = null;
      _pollingTimer = null;
    } else {
      _pollingTimer ??= Timer(MemoryTimeline.updateDelay, _pollMemory);
      _gcStreamListener ??= service?.onGCEvent?.listen(_handleGCEvent);
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
  }

  void _pollMemory() async {
    _pollingTimer = null;

    if (!hasConnection || memoryController.memoryTracker == null) {
      logger.log('VM service connection and/or MemoryTracker lost.');
      return;
    }

    final isolateMemory = <IsolateRef, MemoryUsage>{};
    for (IsolateRef isolateRef in serviceManager.isolateManager.isolates) {
      if (await memoryController.isIsolateLive(isolateRef.id)) {
        isolateMemory[isolateRef] = await service.getMemoryUsage(isolateRef.id);
      }
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

    _pollingTimer ??= Timer(MemoryTimeline.updateDelay, _pollMemory);
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

  /// Poll ADB meminfo
  Future<AdbMemoryInfo> _fetchAdbInfo() async =>
      AdbMemoryInfo.fromJson((await serviceManager.getAdbMemoryInfo()).json);

  /// Returns the MemoryUsage of a particular isolate.
  /// @param id isolateId.
  /// @param usage associated with the passed in isolate's id.
  /// @returns the MemoryUsage of the isolate or null if isolate is a sentinal.
  Future<MemoryUsage> _isolateMemoryUsage(String id, MemoryUsage usage) async =>
      await memoryController.isIsolateLive(id) ? usage : null;

  void _recalculate([bool fromGC = false]) async {
    int used = 0;
    int capacity = 0;
    int external = 0;

    final keysToRemove = <String>[];

    final isolateCount = isolateHeaps.length;
    final keys = isolateHeaps.keys.toList();
    for (var index = 0; index < isolateCount; index++) {
      final isolateId = keys[index];
      var usage = isolateHeaps[isolateId];
      // Check if the isolate is dead (sentinal), null implies sentinal.
      final checkIsolateUsage = await _isolateMemoryUsage(isolateId, usage);
      if (checkIsolateUsage == null && !keysToRemove.contains(isolateId)) {
        // Sentinal Isolate don't include in the heap computation.
        keysToRemove.add(isolateId);
        // Don't use this sential isolate for any heap computation.
        usage = null;
      }

      if (usage != null) {
        // Isolate is live (a null usage implies sentinal).
        used += usage.heapUsage;
        capacity += usage.heapCapacity;
        external += usage.externalUsage;
      }
    }

    // Removes any isolate that is a sentinal.
    isolateHeaps.removeWhere((key, value) => keysToRemove.contains(key));

    int time = DateTime.now().millisecondsSinceEpoch;
    if (samples.isNotEmpty) {
      time = math.max(time, samples.last.timestamp);
    }

    final memoryTimeline = memoryController.memoryTimeline;

    // Process any memory events?
    final eventSample = processEventSample(memoryTimeline, time);

    if (eventSample != null && eventSample.isEventAllocationAccumulator) {
      if (eventSample.allocationAccumulator.isStart) {
        // Stop Continuous events being auto posted - a new start is beginning.
        memoryTimeline.monitorContinuesState = ContinuesState.stop;
      }
    } else if (memoryTimeline.monitorContinuesState == ContinuesState.next) {
      if (_monitorContinues != null) {
        _monitorContinues.cancel();
        _monitorContinues = null;
      }
      _monitorContinues ??= Timer(
        const Duration(milliseconds: 300),
        _recalculate,
      );
    }

    final HeapSample sample = HeapSample(
      time,
      processRss,
      capacity + external,
      used,
      external,
      fromGC,
      adbMemoryInfo,
      eventSample,
    );

    _addSample(sample);
    memoryTimeline.addSample(sample);

    // Signal continues events are to be emitted.  These events are hidden
    // until a reset event then the continuous events between last monitor
    // start/reset and latest reset are made visible.
    if (eventSample != null &&
        eventSample.isEventAllocationAccumulator &&
        eventSample.allocationAccumulator.isStart) {
      memoryTimeline.monitorContinuesState = ContinuesState.next;
    }
  }

  EventSample processEventSample(MemoryTimeline memoryTimeline, int time) {
    EventSample eventSample;
    if (memoryTimeline.anyEvents) {
      final eventTime = memoryTimeline.peekEventTimestamp;
      final timeDuration = Duration(milliseconds: time);
      final eventDuration = Duration(milliseconds: eventTime);

      // If the event is +/- _updateDelay (500 ms) of the current time then
      // associate the EventSample with the current HeapSample.
      const delay = MemoryTimeline.updateDelay;
      final compared = timeDuration.compareTo(eventDuration);
      if (compared < 0) {
        if ((timeDuration + delay).compareTo(eventDuration) >= 0) {
          // Currently, events are all UI events so duration < _updateDelay
          final pulledEvent = memoryTimeline.pullEventSample();
          eventSample = pulledEvent.clone(time);
        } else {
          // Throw away event, missed attempt to attach to a HeapSample.
          final ignoreEvent = memoryTimeline.pullEventSample();
          logger.log('Event duration is lagging ignore event'
              'timestamp: ${MemoryTimeline.fineGrainTimestampFormat(time)} '
              'event: ${MemoryTimeline.fineGrainTimestampFormat(eventTime)}'
              '\n$ignoreEvent');
        }
      } else if (compared > 0) {
        final msDiff = time - eventTime;
        if (msDiff > MemoryTimeline.delayMs) {
          // eventSample is in the future.
          if ((timeDuration - delay).compareTo(eventDuration) >= 0) {
            // Able to match event time to a heap sample. We will attach the
            // EventSample to this HeapSample.
            final pulledEvent = memoryTimeline.pullEventSample();
            eventSample = pulledEvent.clone(time);
          }
        } else {
          // The almost exact eventSample we have.
          eventSample = memoryTimeline.pullEventSample();
        }
        // Keep the event, its time hasn't caught up to the HeapSample time yet.
      }
    }

    return eventSample;
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
      instancesDelta = json['instancesAccumulated'];
      bytesCurrent = json['bytesCurrent'];
      bytesDelta = json['accumulatedSize'];
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
  int instancesDelta = 0;
  int bytesCurrent = 0;
  int bytesDelta = 0;

  ClassRef classRef;

  String get type => json['type'];

  void _update(List<dynamic> stats) {
    instancesDelta += stats[ACCUMULATED];
    bytesDelta += stats[ACCUMULATED_SIZE];
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
