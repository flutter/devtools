// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import '../../config_specific/logger/logger.dart' as logger;
import '../../shared/globals.dart';
import '../../shared/utils.dart';
import 'memory_controller.dart';
import 'memory_screen.dart';
import 'memory_timeline.dart';

class MemoryTracker {
  MemoryTracker(this.memoryController);

  final MemoryController memoryController;

  Timer? _pollingTimer;

  final isolateHeaps = <String, MemoryUsage>{};

  /// Polled VM current RSS.
  late int processRss;

  /// Polled adb dumpsys meminfo values.
  late AdbMemoryInfo adbMemoryInfo;

  /// Polled engine's RasterCache estimates.
  RasterCache? rasterCache;

  Stream<void> get onChange => _changeController.stream;
  final _changeController = StreamController<void>.broadcast();

  StreamSubscription<Event>? _gcStreamListener;

  Timer? _monitorContinues;

  void start() {
    _updateLiveDataPolling();
    memoryController.paused.addListener(_updateLiveDataPolling);
  }

  void _updateLiveDataPolling() {
    if (serviceManager.service == null) {
      // A service of null implies we're disconnected - signal paused.
      memoryController.pauseLiveFeed();
    }

    _pollingTimer ??= Timer(MemoryTimeline.updateDelay, _pollMemory);
    _gcStreamListener ??=
        serviceManager.service?.onGCEvent.listen(_handleGCEvent);
  }

  void stop() {
    _updateLiveDataPolling();
    memoryController.paused.removeListener(_updateLiveDataPolling);

    _pollingTimer?.cancel();
    _gcStreamListener?.cancel();
    _gcStreamListener = null;
    _pollingTimer = null;
  }

  void _handleGCEvent(Event event) {
    final HeapSpace newHeap = HeapSpace.parse(event.json!['new'])!;
    final HeapSpace oldHeap = HeapSpace.parse(event.json!['old'])!;

    final MemoryUsage memoryUsage = MemoryUsage(
      externalUsage: newHeap.external! + oldHeap.external!,
      heapCapacity: newHeap.capacity! + oldHeap.capacity!,
      heapUsage: newHeap.used! + oldHeap.used!,
    );

    _updateGCEvent(event.isolate!.id!, memoryUsage);
  }

  void _pollMemory() async {
    _pollingTimer = null;

    if (!serviceManager.hasConnection ||
        memoryController.memoryTracker == null) {
      logger.log('VM service connection and/or MemoryTracker lost.');
      return;
    }

    final isolateMemory = <IsolateRef, MemoryUsage>{};
    for (IsolateRef isolateRef
        in serviceManager.isolateManager.isolates.value) {
      if (await memoryController.isIsolateLive(isolateRef.id!)) {
        isolateMemory[isolateRef] =
            await serviceManager.service!.getMemoryUsage(isolateRef.id!);
      }
    }

    // Polls for current Android meminfo using:
    //    > adb shell dumpsys meminfo -d <package_name>
    if (serviceManager.hasConnection &&
        serviceManager.vm!.operatingSystem == 'android' &&
        memoryController.androidCollectionEnabled.value) {
      adbMemoryInfo = await _fetchAdbInfo();
    } else {
      // TODO(terry): TBD alternative for iOS memory info - all values zero.
      adbMemoryInfo = AdbMemoryInfo.empty();
    }

    // Query the engine's rasterCache estimate.
    rasterCache = await _fetchRasterCacheInfo();

    // Polls for current RSS size.
    final vm = await serviceManager.service!.getVM();
    _update(vm, isolateMemory);

    // TODO(terry): Is there a better way to detect an integration test running?
    if (vm.json!.containsKey('_FAKE_VM')) return;

    _pollingTimer ??= Timer(MemoryTimeline.updateDelay, _pollMemory);
  }

  void _update(VM vm, Map<IsolateRef, MemoryUsage> isolateMemory) {
    processRss = vm.json!['_currentRSS'];

    isolateHeaps.clear();

    for (IsolateRef isolateRef in isolateMemory.keys) {
      isolateHeaps[isolateRef.id!] = isolateMemory[isolateRef]!;
    }

    _recalculate();
  }

  void _updateGCEvent(String isolateId, MemoryUsage memoryUsage) {
    isolateHeaps[isolateId] = memoryUsage;
    _recalculate(true);
  }

  /// Poll Fultter engine's Raster Cache metrics.
  /// @returns engine's rasterCache estimates or null.
  Future<RasterCache?> _fetchRasterCacheInfo() async {
    final response = await serviceManager.rasterCacheMetrics;
    if (response == null) return null;
    final rasterCache = RasterCache.parse(response.json);
    return rasterCache;
  }

  /// Poll ADB meminfo, ADB returns values in KB convert to total bytes.
  Future<AdbMemoryInfo> _fetchAdbInfo() async => AdbMemoryInfo.fromJsonInKB(
        (await serviceManager.adbMemoryInfo).json!,
      );

  /// Returns the MemoryUsage of a particular isolate.
  /// @param id isolateId.
  /// @param usage associated with the passed in isolate's id.
  /// @returns the MemoryUsage of the isolate or null if isolate is a sentinal.
  Future<MemoryUsage?> _isolateMemoryUsage(
    String id,
    MemoryUsage? usage,
  ) async =>
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
        used += usage.heapUsage!;
        capacity += usage.heapCapacity!;
        external += usage.externalUsage!;
      }
    }

    // Removes any isolate that is a sentinal.
    isolateHeaps.removeWhere((key, value) => keysToRemove.contains(key));

    final memoryTimeline = memoryController.memoryTimeline;

    int time = DateTime.now().millisecondsSinceEpoch;
    if (memoryTimeline.data.isNotEmpty) {
      time = math.max(time, memoryTimeline.data.last.timestamp);
    }

    // Process any memory events?
    final eventSample = processEventSample(memoryTimeline, time);

    if (eventSample != null && eventSample.isEventAllocationAccumulator) {
      if (eventSample.allocationAccumulator!.isStart) {
        // Stop Continuous events being auto posted - a new start is beginning.
        memoryTimeline.monitorContinuesState = ContinuesState.stop;
      }
    } else if (memoryTimeline.monitorContinuesState == ContinuesState.next) {
      if (_monitorContinues != null) {
        _monitorContinues!.cancel();
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
      // Displaying capacity dashed line on top of stacked (used + external).
      capacity + external,
      used,
      external,
      fromGC,
      adbMemoryInfo,
      eventSample,
      rasterCache,
    );

    memoryTimeline.addSample(sample);

    _changeController.add(null);

    // Signal continues events are to be emitted.  These events are hidden
    // until a reset event then the continuous events between last monitor
    // start/reset and latest reset are made visible.
    if (eventSample != null &&
        eventSample.isEventAllocationAccumulator &&
        eventSample.allocationAccumulator!.isStart) {
      memoryTimeline.monitorContinuesState = ContinuesState.next;
    }
  }

  /// Many extension events could arrive between memory collection ticks, those
  /// events need to be associated with a particular memory tick (timestamp). This
  /// routine collects those new events received that are closest to a tick
  /// (time parameter)).
  /// @returns copy of events to associate with an existing HeapSample tick
  /// (contained in the EventSample). See [processEventSample] it computes the
  /// events to aggregate to an existing HeapSample or delay associating those
  /// events until the next HeapSample (tick) received see [_recalculate].
  EventSample pullClone(MemoryTimeline memoryTimeline, int time) {
    final pulledEvent = memoryTimeline.pullEventSample();
    final extensionEvents = memoryTimeline.extensionEvents;
    final eventSample = pulledEvent.clone(
      time,
      extensionEvents: extensionEvents,
    );
    if (extensionEvents?.isNotEmpty == true) {
      debugLogger('ExtensionEvents Received');
    }

    return eventSample;
  }

  EventSample? processEventSample(MemoryTimeline memoryTimeline, int time) {
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
          return pullClone(memoryTimeline, time);
        }
        // Throw away event, missed attempt to attach to a HeapSample.
        final ignoreEvent = memoryTimeline.pullEventSample();
        logger.log(
          'Event duration is lagging ignore event'
          'timestamp: ${MemoryTimeline.fineGrainTimestampFormat(time)} '
          'event: ${MemoryTimeline.fineGrainTimestampFormat(eventTime)}'
          '\n$ignoreEvent',
        );
        return null;
      }

      if (compared > 0) {
        final msDiff = time - eventTime;
        if (msDiff > MemoryTimeline.delayMs) {
          // eventSample is in the future.
          if ((timeDuration - delay).compareTo(eventDuration) >= 0) {
            // Able to match event time to a heap sample. We will attach the
            // EventSample to this HeapSample.
            return pullClone(memoryTimeline, time);
          }
          // Keep the event, its time hasn't caught up to the HeapSample time yet.
          return null;
        }
        // The almost exact eventSample we have.
        return pullClone(memoryTimeline, time);
      }
    }

    if (memoryTimeline.anyPendingExtensionEvents) {
      final extensionEvents = memoryTimeline.extensionEvents;

      if (MemoryScreen.isDebuggingEnabled &&
          extensionEvents?.isNotEmpty == true) {
        debugLogger(
          'Receieved Extension Events '
          '${extensionEvents!.theEvents.length}',
        );
        for (var e in extensionEvents.theEvents) {
          final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp!);
          debugLogger(
            '  ${e.eventKind} ${e.customEventName} '
            '$dt ${e.data!['param']}',
          );
        }
      }
      return EventSample.extensionEvent(time, extensionEvents);
    }

    return null;
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

const int ALLOCATED_BEFORE_GC = 0;
const int ALLOCATED_BEFORE_GC_SIZE = 1;
const int LIVE_AFTER_GC = 2;
const int LIVE_AFTER_GC_SIZE = 3;
const int ALLOCATED_SINCE_GC = 4;
const int ALLOCATED_SINCE_GC_SIZE = 5;
const int ACCUMULATED = 6;
const int ACCUMULATED_SIZE = 7;

ClassHeapDetailStats parseJsonClassHeapStats(Map<String, dynamic> json) {
  int instancesCurrent = 0;
  int instancesDelta = 0;
  int bytesCurrent = 0;
  int bytesDelta = 0;

  final classRef = ClassRef.parse(json['class'])!;
  instancesCurrent = json['instancesCurrent'];
  instancesDelta = json['instancesAccumulated'];
  bytesCurrent = json['bytesCurrent'];
  bytesDelta = json['accumulatedSize'];

  return ClassHeapDetailStats(
    classRef,
    bytes: bytesCurrent,
    deltaBytes: bytesDelta,
    instances: instancesCurrent,
    deltaInstances: instancesDelta,
  );
}

class InstanceSummary {
  InstanceSummary(this.classRef, this.className, this.objectRef);

  final String classRef;
  final String className;
  final String? objectRef;

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
