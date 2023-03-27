// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/analytics/metrics.dart';
import '../../../../shared/feature_flags.dart';
import '../../../../shared/future_work_tracker.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/http/http_service.dart' as http_service;
import '../../../../shared/primitives/auto_dispose.dart';
import '../../../../shared/primitives/trace_event.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_controller.dart';
import '../../performance_model.dart';
import '../../performance_utils.dart';
import '../flutter_frames/flutter_frame_model.dart';
import 'legacy/legacy_events_controller.dart';
import 'perfetto/perfetto_controller.dart';
import 'timeline_event_processor.dart';

final _log = Logger('timeline_events_controller');

enum EventsControllerStatus {
  empty,
  processing,
  ready,
}

class TimelineEventsController extends PerformanceFeatureController
    with AutoDisposeControllerMixin {
  TimelineEventsController(super.performanceController) {
    legacyController = LegacyTimelineEventsController(performanceController);
    perfettoController = createPerfettoController(performanceController, this);
    addAutoDisposeListener(_workTracker.active, () {
      final active = _workTracker.active.value;
      if (active) {
        _status.value = EventsControllerStatus.processing;
      } else {
        _status.value = EventsControllerStatus.ready;
      }
    });
  }

  /// Controller that contains business logic for the legacy trace viewer.
  ///
  /// This controller will be used when [useLegacyTraceViewer.value] is true.
  late final LegacyTimelineEventsController legacyController;

  /// Controller that contains business logic for the Perfetto trace viewer.
  ///
  /// This controller will be used when [useLegacyTraceViewer.value] is false.
  late final PerfettoController perfettoController;

  /// Trace events in the current timeline.
  ///
  /// This list is cleared and repopulated each time "Refresh" is clicked.
  final allTraceEvents = <TraceEventWrapper>[];

  /// Set of thread_name trace events.
  ///
  /// Thread name events are returned with each [VMService.getVMTimeline]
  /// response, and we do not want to store duplicates in [allTraceEvents].
  final threadNameEvents = <ThreadNameEvent>{};

  /// Maps thread names, which are gathererd from the "thread_name" trace
  /// events, to their thread ids.
  final threadNamesById = <int, String>{};

  /// Whether we should be using the legacy trace viewer or the new Perfetto
  /// trace viewer.
  final useLegacyTraceViewer =
      ValueNotifier<bool>(!FeatureFlags.embeddedPerfetto || !kIsWeb);

  bool get _perfettoMode =>
      FeatureFlags.embeddedPerfetto && !useLegacyTraceViewer.value;

  /// Whether the recorded timeline data is currently being processed.
  ValueListenable<EventsControllerStatus> get status => _status;
  final _status =
      ValueNotifier<EventsControllerStatus>(EventsControllerStatus.empty);

  final _workTracker = FutureWorkTracker();

  // TODO(jacobr): this isn't accurate. Another page of DevTools
  // or a different instance of DevTools could change this value. We need to
  // sync the value with the server like we do for other vm service extensions
  // that we track with the vm service extension manager.
  // See https://github.com/dart-lang/sdk/issues/41823.
  /// Whether http timeline logging is enabled.
  ValueListenable<bool> get httpTimelineLoggingEnabled =>
      _httpTimelineLoggingEnabled;
  final _httpTimelineLoggingEnabled = ValueNotifier<bool>(false);

  Timer? _pollingTimer;

  int _nextPollStartMicros = 0;

  static const _timelinePollingRateLimit = 1.0;

  Duration get _timelinePollingInterval =>
      _perfettoMode ? const Duration(seconds: 1) : const Duration(seconds: 2);

  RateLimiter? _timelinePollingRateLimiter;

  /// The tracking index for the first unprocessed trace event collected.
  int _nextTraceIndexToProcess = 0;

  /// The collection of [TimelineEvent]s that should be linked to
  /// [FlutterFrame]s but have not yet been assigned.
  ///
  /// These timeline events are keyed by the [FlutterFrame] ID specified in the
  /// event arguments, which matches the ID for the corresponding
  /// [FlutterFrame].
  final _unassignedFlutterFrameEvents = <int, FrameTimelineEventData>{};

  @override
  Future<void> init() async {
    if (FeatureFlags.embeddedPerfetto) {
      perfettoController.init();
    }

    if (!offlineController.offlineMode.value) {
      await _initForServiceConnection();
    }
  }

  @override
  void onBecomingActive() {
    if (_perfettoMode) {
      perfettoController.onBecomingActive();
    }
  }

  Future<void> _initForServiceConnection() async {
    legacyController.init();
    await serviceManager.timelineStreamManager.setDefaultTimelineStreams();
    await toggleHttpRequestLogging(true);

    autoDisposeStreamSubscription(
      serviceManager.onConnectionClosed.listen((_) {
        _pollingTimer?.cancel();
        _timelinePollingRateLimiter?.dispose();
      }),
    );

    // Load available timeline events.
    await _pullTraceEventsFromVmTimeline(isInitialPull: true);

    await processAllTraceEvents();

    _timelinePollingRateLimiter = RateLimiter(
      _timelinePollingRateLimit,
      _pullTraceEventsFromVmTimeline,
    );

    // Poll for new timeline events.
    // We are polling here instead of listening to the timeline event stream
    // because the event stream is sending out of order and duplicate events.
    // See https://github.com/dart-lang/sdk/issues/46605.
    _pollingTimer = Timer.periodic(_timelinePollingInterval, (_) {
      _timelinePollingRateLimiter!.scheduleRequest();
    });
  }

  Future<void> _pullTraceEventsFromVmTimeline({
    bool isInitialPull = false,
  }) async {
    final service = serviceManager.service;
    if (service == null) return;
    final currentVmTime = await service.getVMTimelineMicros();
    debugTraceEventCallback(
      () => _log.info(
        'pulling trace events from '
        '[$_nextPollStartMicros - ${currentVmTime.timestamp}]',
      ),
    );
    final timeline = await service.getVMTimeline(
      timeOriginMicros: _nextPollStartMicros,
      timeExtentMicros: currentVmTime.timestamp! - _nextPollStartMicros,
    );
    _nextPollStartMicros = currentVmTime.timestamp! + 1;

    final newThreadNameEvents = <ThreadNameEvent>[];
    for (final event in timeline.traceEvents ?? []) {
      final traceEvent = TraceEvent(event.json!);
      final eventWrapper = TraceEventWrapper(
        traceEvent,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Special handling for thread name events since they are returned with
      // each [VMService.getVMTimeline] response.
      if (traceEvent.isThreadNameEvent) {
        final threadNameEvent = ThreadNameEvent.from(traceEvent);
        final added = threadNameEvents.add(threadNameEvent);
        if (added) {
          // Only add this thread name event to [allTraceEvents] if we have not
          // already added it. Otherwise, it will be a duplicate and will
          // consume unecessary space and processing time.
          newThreadNameEvents.add(threadNameEvent);
          allTraceEvents.add(eventWrapper);
        }
      } else {
        allTraceEvents.add(eventWrapper);
      }
    }

    updateThreadIds(newThreadNameEvents, isInitialUpdate: isInitialPull);
  }

  void updateThreadIds(
    List<ThreadNameEvent> threadNameEvents, {
    bool isInitialUpdate = false,
  }) {
    // This can happen if there is a race between this method being called and
    // losing connection to the app.
    if (serviceManager.connectedApp == null) return;

    final offlineData = performanceController.offlinePerformanceData;
    final isFlutterApp = offlineController.offlineMode.value
        ? offlineData != null && offlineData.frames.isNotEmpty
        : serviceManager.connectedApp!.isFlutterAppNow!;

    // TODO(kenz): Remove this logic once ui/raster distinction changes are
    // available in the engine.
    int? uiThreadId;
    int? rasterThreadId;
    for (ThreadNameEvent event in threadNameEvents) {
      final name = event.name!;
      if (isFlutterApp && isInitialUpdate) {
        // Android: "1.ui (12652)"
        // iOS: "io.flutter.1.ui (12652)"
        // MacOS, Linux, Windows, Dream (g3): "io.flutter.ui (225695)"
        if (name.contains('.ui')) {
          uiThreadId = event.threadId;
        }

        // Android: "1.raster (12651)"
        // iOS: "io.flutter.1.raster (12651)"
        // Linux, Windows, Dream (g3): "io.flutter.raster (12651)"
        // MacOS: Does not exist
        // Also look for .gpu here for older versions of Flutter.
        // TODO(kenz): remove check for .gpu name in April 2021.
        if (name.contains('.raster') || name.contains('.gpu')) {
          rasterThreadId = event.threadId;
        }

        // Android: "1.platform (22585)"
        // iOS: "io.flutter.1.platform (22585)"
        // MacOS, Linux, Windows, Dream (g3): "io.flutter.platform (22596)"
        if (name.contains('.platform')) {
          // MacOS and Flutter apps with platform views do not have a .gpu
          // thread. In these cases, the "Raster" events will come on the
          // .platform thread instead.
          rasterThreadId ??= event.threadId;
        }
      }

      threadNamesById[event.threadId!] = name;
    }

    if (isFlutterApp && isInitialUpdate) {
      if (uiThreadId == null || rasterThreadId == null) {
        _log.info(
          'Could not find UI thread and / or Raster thread from names: '
          '${threadNamesById.values}',
        );
      }

      _primeThreadIds(uiThreadId: uiThreadId, rasterThreadId: rasterThreadId);
    }
  }

  Future<void> processAllTraceEvents() async {
    await _workTracker.track(_processAllTraceEvents);
  }

  Future<void> _processAllTraceEvents() async {
    if (_perfettoMode) {
      final traceEventCount = allTraceEvents.length;
      debugTraceEventCallback(
        () => _log.info(
          'processing traceEvents at startIndex '
          '$_nextTraceIndexToProcess',
        ),
      );
      final processingTraceCount = traceEventCount - _nextTraceIndexToProcess;
      Future<void> processTraceEventsHelper() async {
        await perfettoController.processor.processData(
          allTraceEvents,
          startIndex: _nextTraceIndexToProcess,
        );
        debugTraceEventCallback(
          () => _log.info(
            'after processing traceEvents at startIndex $_nextTraceIndexToProcess, '
            'and now _nextTraceIndexToProcess = $traceEventCount',
          ),
        );
        _nextTraceIndexToProcess = traceEventCount;
      }

      // Process trace events [processTraceEventsHelper] and time the operation
      // for analytics.
      await ga.timeAsync(
        gac.performance,
        gac.perfettoModeTraceEventProcessingTime,
        asyncOperation: processTraceEventsHelper,
        screenMetricsProvider: () => PerformanceScreenMetrics(
          traceEventCount: processingTraceCount,
        ),
      );
      await perfettoController.loadTrace(allTraceEvents);
    } else {
      await legacyController.processTraceEvents(
        allTraceEvents,
        threadNamesById: threadNamesById,
      );
    }
  }

  Future<void> selectTimelineEvent(
    TimelineEvent? event, {
    bool updateProfiler = true,
  }) async {
    if (useLegacyTraceViewer.value) {
      await legacyController.selectTimelineEvent(
        event,
        updateProfiler: updateProfiler,
      );
    } else {
      // TODO(kenz): handle event selection from Perfetto here if we ever have
      // a use case for this.
    }
  }

  @override
  Future<void> handleSelectedFrame(FlutterFrame frame) async {
    if (useLegacyTraceViewer.value) {
      await _legacySelectFrame(frame);
    } else if (FeatureFlags.embeddedPerfetto) {
      await _perfettoSelectFrame(frame);
    }

    debugTraceEventCallback(() {
      final buf = StringBuffer();
      buf.writeln('UI timeline event for frame ${frame.id}:');
      frame.timelineEventData.uiEvent?.format(buf, '  ');
      buf.writeln('\nUI trace for frame ${frame.id}');
      frame.timelineEventData.uiEvent?.writeTraceToBuffer(buf);
      buf.writeln('\Raster timeline event frame ${frame.id}:');
      frame.timelineEventData.rasterEvent?.format(buf, '  ');
      buf.writeln('\nRaster trace for frame ${frame.id}');
      frame.timelineEventData.rasterEvent?.writeTraceToBuffer(buf);
      _log.info(buf.toString());
    });
  }

  Future<void> _perfettoSelectFrame(FlutterFrame frame) async {
    if (!offlineController.offlineMode.value) {
      bool hasProcessedTimelineEventsForFrame =
          perfettoController.processor.hasProcessedEventsForFrame(frame.id);
      // No need to process events again if we are in offline mode - we have
      // already processed all the available data.
      if (!hasProcessedTimelineEventsForFrame) {
        await processAllTraceEvents();
      }

      // If we still have not processed the timeline events for this frame,
      // wait a short delay and try to process events again after the
      // VM has been polled one more time.
      hasProcessedTimelineEventsForFrame =
          perfettoController.processor.hasProcessedEventsForFrame(frame.id);
      if (!hasProcessedTimelineEventsForFrame) {
        await _workTracker.track(
          () => Future.delayed(
            _timelinePollingInterval,
            _processAllTraceEvents,
          ),
        );
      }
    }

    perfettoController.scrollToTimeRange(frame.timeFromFrameTiming);
  }

  Future<void> _legacySelectFrame(FlutterFrame frame) async {
    final framesController = performanceController.flutterFramesController;
    if (!offlineController.offlineMode.value) {
      final firstWellFormedFrameMicros =
          framesController.firstWellFormedFrameMicros;
      final bool frameBeforeFirstWellFormedFrame =
          firstWellFormedFrameMicros != null &&
              frame.timeFromFrameTiming.start!.inMicroseconds <
                  firstWellFormedFrameMicros;
      if (!frame.isWellFormed && !frameBeforeFirstWellFormedFrame) {
        // Only try to pull timeline events for frames that are after the first
        // well formed frame. Timeline events that occurred before this frame will
        // have already fallen out of the buffer.
        await processAllTraceEvents();
      }

      if (framesController.currentFrameBeingSelected != frame) return;

      // If the frame is still not well formed after processing all available
      // events, wait a short delay and try to process events again after the
      // VM has been polled one more time.
      if (!frame.isWellFormed && !frameBeforeFirstWellFormedFrame) {
        await _workTracker.track(
          () => Future.delayed(_timelinePollingInterval, () async {
            if (framesController.currentFrameBeingSelected != frame) return;
            return await _processAllTraceEvents();
          }),
        );
      }

      if (framesController.currentFrameBeingSelected != frame) return;
    }

    // We do not need to pull the CPU profile because we will pull the profile
    // for the entire frame. The order of selecting the timeline event and
    // pulling the CPU profile for the frame (directly below) matters here.
    // If the selected timeline event is null, the event details section will
    // not show the progress bar while we are processing the CPU profile.
    await selectTimelineEvent(
      frame.timelineEventData.uiEvent,
      updateProfiler: false,
    );

    if (framesController.currentFrameBeingSelected != frame) return;

    await legacyController.updateCpuProfileForFrame(frame);
  }

  void addTimelineEvent(TimelineEvent event) {
    data!.addTimelineEvent(event);
    if (event is SyncTimelineEvent) {
      if (!offlineController.offlineMode.value &&
          serviceManager.hasConnection &&
          !serviceManager.connectedApp!.isFlutterAppNow!) {
        return;
      }

      for (final frameEvent in event.uiFrameEvents) {
        _maybeAddEventToUnassignedFrame(
          frameEvent.flutterFrameNumber,
          frameEvent,
          TimelineEventType.ui,
        );
      }
      for (final frameEvent in event.rasterFrameEvents) {
        _maybeAddEventToUnassignedFrame(
          frameEvent.flutterFrameNumber,
          frameEvent,
          TimelineEventType.raster,
        );
      }
    }
  }

  void _maybeAddEventToUnassignedFrame(
    int? frameNumber,
    SyncTimelineEvent event,
    TimelineEventType type,
  ) {
    if (frameNumber != null && (event.isUiEvent || event.isRasterEvent)) {
      if (performanceController.flutterFramesController
          .hasUnassignedFlutterFrame(frameNumber)) {
        performanceController.flutterFramesController
            .assignEventToFrame(frameNumber, event, type);
      } else {
        final unassignedEventsForFrame =
            _unassignedFlutterFrameEvents.putIfAbsent(
          frameNumber,
          () => FrameTimelineEventData(),
        );
        unassignedEventsForFrame.setEventFlow(
          event: event,
          type: event.type,
          setTimeData: false,
        );
      }
    }
  }

  void maybeAddUnassignedEventsToFrame(FlutterFrame frame) {
    _maybeAddUnassignedEventToFrame(frame, TimelineEventType.ui);
    _maybeAddUnassignedEventToFrame(frame, TimelineEventType.raster);
    if (frame.isWellFormed) {
      _unassignedFlutterFrameEvents.remove(frame.id);
    }
  }

  void _maybeAddUnassignedEventToFrame(
    FlutterFrame frame,
    TimelineEventType type,
  ) {
    final event = _unassignedFlutterFrameEvents[frame.id]?.eventByType(type);
    if (event != null) {
      frame.setEventFlow(event, type: type);
    }
  }

  Future<void> toggleHttpRequestLogging(bool state) async {
    await http_service.toggleHttpRequestLogging(state);
    _httpTimelineLoggingEnabled.value = state;
  }

  Future<void> toggleUseLegacyTraceViewer(bool? value) async {
    useLegacyTraceViewer.value = value ?? false;
    await processAllTraceEvents();
  }

  void recordTrace(Map<String, dynamic> trace) {
    data!.traceEvents.add(trace);
  }

  void _primeThreadIds({
    required int? uiThreadId,
    required int? rasterThreadId,
  }) {
    legacyController.processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
    perfettoController.processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
  }

  int _threadIdForEvents(
    Set<String> targetEventNames,
    List<TraceEventWrapper> traceEvents,
  ) {
    const invalidThreadId = -1;
    return traceEvents
            .firstWhereOrNull(
              (trace) => targetEventNames.contains(trace.event.name),
            )
            ?.event
            .threadId ??
        invalidThreadId;
  }

  @override
  Future<void> setOfflineData(PerformanceData offlineData) async {
    final traceEvents = [
      for (var trace in offlineData.traceEvents)
        TraceEventWrapper(
          TraceEvent(trace),
          DateTime.now().microsecondsSinceEpoch,
        ),
    ];
    allTraceEvents
      ..clear()
      ..addAll(traceEvents);

    final uiThreadId = _threadIdForEvents({uiEventName}, traceEvents);
    final rasterThreadId = _threadIdForEvents({rasterEventName}, traceEvents);
    _primeThreadIds(uiThreadId: uiThreadId, rasterThreadId: rasterThreadId);
    await processAllTraceEvents();

    await legacyController.setOfflineData(offlineData);

    if (offlineData.selectedFrame != null && _perfettoMode) {
      perfettoController
          .scrollToTimeRange(offlineData.selectedFrame!.timeFromFrameTiming);
    }
  }

  @override
  Future<void> clearData() async {
    allTraceEvents.clear();
    threadNameEvents.clear();
    _nextTraceIndexToProcess = 0;
    _unassignedFlutterFrameEvents.clear();

    threadNamesById.clear();
    _workTracker.clear();
    legacyController.clearData();
    _status.value = EventsControllerStatus.empty;
    if (FeatureFlags.embeddedPerfetto) {
      await perfettoController.clear();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timelinePollingRateLimiter?.dispose();
    legacyController.dispose();
    if (FeatureFlags.embeddedPerfetto) {
      perfettoController.dispose();
    }
    super.dispose();
  }
}
