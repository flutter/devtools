// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/primitives/memory_timeline.dart';

final _log = Logger('memory_protocol');

enum _ContinuesState {
  none,
  stop,
  next,
}

class MemoryTracker {
  MemoryTracker(
    this.timeline, {
    required this.paused,
    required this.isAndroidChartVisible,
  });

  final MemoryTimeline timeline;
  final ValueListenable<bool> paused;
  final ValueNotifier<bool> isAndroidChartVisible;
  _ContinuesState _monitorContinuesState = _ContinuesState.none;

  Timer? _pollingTimer;

  final isolateHeaps = <String, MemoryUsage>{};

  /// Polled VM current RSS.
  int processRss = 0;

  /// Polled adb dumpsys meminfo values.
  AdbMemoryInfo? adbMemoryInfo;

  /// Polled engine's RasterCache estimates.
  RasterCache? rasterCache;

  StreamSubscription<Event>? _gcStreamListener;

  Timer? _monitorContinues;

  void start() {
    _updateLiveDataPolling();
    paused.addListener(_updateLiveDataPolling);
  }

  void _updateLiveDataPolling() {
    _pollingTimer ??= Timer(MemoryTimeline.updateDelay, _pollMemory);
    _gcStreamListener ??= serviceConnection.serviceManager.service?.onGCEvent
        .listen(_handleGCEvent);
  }

  void stop() {
    _updateLiveDataPolling();
    _cleanListenersAndTimers();
  }

  void _cleanListenersAndTimers() {
    paused.removeListener(_updateLiveDataPolling);

    _pollingTimer?.cancel();
    unawaited(_gcStreamListener?.cancel());
    _pollingTimer = null;
    _gcStreamListener = null;
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

    final isolateMemory = <IsolateRef, MemoryUsage>{};
    for (IsolateRef isolateRef
        in serviceConnection.serviceManager.isolateManager.isolates.value) {
      if (await _isIsolateLive(isolateRef.id!)) {
        isolateMemory[isolateRef] = await serviceConnection
            .serviceManager.service!
            .getMemoryUsage(isolateRef.id!);
      }
    }

    // Polls for current Android meminfo using:
    //    > adb shell dumpsys meminfo -d <package_name>
    adbMemoryInfo = serviceConnection.serviceManager.hasConnection &&
            serviceConnection.serviceManager.vm!.operatingSystem == 'android' &&
            isAndroidChartVisible.value
        ? await _fetchAdbInfo()
        : AdbMemoryInfo.empty();

    // Query the engine's rasterCache estimate.
    rasterCache = await _fetchRasterCacheInfo();

    // Polls for current RSS size.
    final vm = await serviceConnection.serviceManager.service!.getVM();
    _update(vm, isolateMemory);

    // TODO(terry): Is there a better way to detect an integration test running?
    if (vm.json!.containsKey('_FAKE_VM')) return;

    _pollingTimer ??= Timer(MemoryTimeline.updateDelay, _pollMemory);
  }

  /// Detect stale isolates (sentineled), may happen after a hot restart.
  static Future<bool> _isIsolateLive(String isolateId) async {
    try {
      final service = serviceConnection.serviceManager.service!;
      await service.getIsolate(isolateId);
    } catch (e) {
      if (e is SentinelException) {
        final SentinelException sentinelErr = e;
        final message = 'isIsolateLive: Isolate sentinel $isolateId '
            '${sentinelErr.sentinel.kind}';
        debugLogger(message);
        return false;
      }
    }
    return true;
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

  /// Fetch the Flutter engine's Raster Cache metrics.
  ///
  /// Returns engine's rasterCache estimates or null.
  Future<RasterCache?> _fetchRasterCacheInfo() async {
    final response = await serviceConnection.rasterCacheMetrics;
    if (response == null) return null;
    final rasterCache = RasterCache.parse(response.json);
    return rasterCache;
  }

  /// Fetch ADB meminfo, ADB returns values in KB convert to total bytes.
  Future<AdbMemoryInfo> _fetchAdbInfo() async => AdbMemoryInfo.fromJsonInKB(
        (await serviceConnection.adbMemoryInfo).json!,
      );

  /// Returns the MemoryUsage of a particular isolate.
  ///
  /// `id`: id for the isolate
  /// `usage`: usage associated with the passed in isolate's id.
  ///
  /// Returns the MemoryUsage of the isolate or null if isolate is a sentinel.
  Future<MemoryUsage?> _isolateMemoryUsage(
    String id,
    MemoryUsage? usage,
  ) async =>
      await _isIsolateLive(id) ? usage : null;

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
      // Check if the isolate is dead (sentinel), null implies sentinel.
      final checkIsolateUsage = await _isolateMemoryUsage(isolateId, usage);
      if (checkIsolateUsage == null && !keysToRemove.contains(isolateId)) {
        // Sentinel Isolate don't include in the heap computation.
        keysToRemove.add(isolateId);
        // Don't use this sentinel isolate for any heap computation.
        usage = null;
      }

      if (usage != null) {
        // Isolate is live (a null usage implies sentinel).
        used += usage.heapUsage!;
        capacity += usage.heapCapacity!;
        external += usage.externalUsage!;
      }
    }

    // Removes any isolate that is a sentinel.
    isolateHeaps.removeWhere((key, value) => keysToRemove.contains(key));

    int time = DateTime.now().millisecondsSinceEpoch;
    if (timeline.data.isNotEmpty) {
      time = math.max(time, timeline.data.last.timestamp);
    }

    // Process any memory events?
    final eventSample = _processEventSample(timeline, time);

    if (eventSample != null && eventSample.isEventAllocationAccumulator) {
      if (eventSample.allocationAccumulator!.isStart) {
        // Stop Continuous events being auto posted - a new start is beginning.
        _monitorContinuesState = _ContinuesState.stop;
      }
    } else if (_monitorContinuesState == _ContinuesState.next) {
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

    timeline.addSample(sample);

    // Signal continues events are to be emitted.  These events are hidden
    // until a reset event then the continuous events between last monitor
    // start/reset and latest reset are made visible.
    if (eventSample != null &&
        eventSample.isEventAllocationAccumulator &&
        eventSample.allocationAccumulator!.isStart) {
      _monitorContinuesState = _ContinuesState.next;
    }
  }

  /// Many extension events could arrive between memory collection ticks, those
  /// events need to be associated with a particular memory tick (timestamp).
  ///
  /// This routine collects those new events received that are closest to a tick
  /// (time parameter)).
  ///
  /// Returns copy of events to associate with an existing HeapSample tick
  /// (contained in the EventSample). See [_processEventSample] it computes the
  /// events to aggregate to an existing HeapSample or delay associating those
  /// events until the next HeapSample (tick) received see [_recalculate].
  EventSample _pullClone(MemoryTimeline memoryTimeline, int time) {
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

  EventSample? _processEventSample(MemoryTimeline memoryTimeline, int time) {
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
          return _pullClone(memoryTimeline, time);
        }
        // Throw away event, missed attempt to attach to a HeapSample.
        final ignoreEvent = memoryTimeline.pullEventSample();
        _log.info(
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
            return _pullClone(memoryTimeline, time);
          }
          // Keep the event, its time hasn't caught up to the HeapSample time yet.
          return null;
        }
        // The almost exact eventSample we have.
        return _pullClone(memoryTimeline, time);
      }
    }

    if (memoryTimeline.anyPendingExtensionEvents) {
      final extensionEvents = memoryTimeline.extensionEvents;
      return EventSample.extensionEvent(time, extensionEvents);
    }

    return null;
  }

  void dispose() {
    _cleanListenersAndTimers();
  }
}
