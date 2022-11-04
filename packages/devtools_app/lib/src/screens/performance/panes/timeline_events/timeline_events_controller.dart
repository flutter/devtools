// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../config_specific/logger/allowed_error.dart';
import '../../../../config_specific/logger/logger.dart';
import '../../../../http/http_service.dart';
import '../../../../primitives/auto_dispose.dart';
import '../../../../primitives/feature_flags.dart';
import '../../../../primitives/trace_event.dart';
import '../../../../primitives/trees.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/globals.dart';
import '../../../../ui/search.dart';
import '../../../profiler/cpu_profile_controller.dart';
import '../../../profiler/cpu_profile_model.dart';
import '../../../profiler/cpu_profile_service.dart';
import '../../../profiler/profile_granularity.dart';
import '../../performance_controller.dart';
import '../../performance_model.dart';
import '../../performance_screen.dart';
import '../../performance_utils.dart';
import '../../simple_trace_example.dart';
import '../flutter_frames/flutter_frame_model.dart';
import 'perfetto/perfetto.dart';
import 'timeline_event_processor.dart';

/// Debugging flag to load sample trace events from [simple_trace_example.dart].
bool debugSimpleTrace = false;

class TimelineEventsController extends PerformanceFeatureController
    with AutoDisposeControllerMixin {
  TimelineEventsController(super.performanceController) {
    legacyController = LegacyTimelineEventsController(performanceController);
  }

  late final LegacyTimelineEventsController legacyController;

  final perfettoController = createPerfettoController();

  /// Trace events in the current timeline.
  ///
  /// This list is cleared and repopulated each time "Refresh" is clicked.
  final allTraceEvents = <TraceEventWrapper>[];

  final threadNamesById = <int, String>{};

  final useLegacyTraceViewer =
      ValueNotifier<bool>(!FeatureFlags.embeddedPerfetto || !kIsWeb);

  /// Whether the recorded timeline data is currently being processed.
  ValueListenable<bool> get processing => _processing;
  final _processing = ValueNotifier<bool>(false);

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

  static const timelinePollingRateLimit = 5.0;

  static const timelinePollingInterval = Duration(seconds: 1);

  RateLimiter? _timelinePollingRateLimiter;

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

    _processing.value = true;
    await processTraceEvents(allTraceEvents);
    _processing.value = false;

    _timelinePollingRateLimiter = RateLimiter(
      timelinePollingRateLimit,
      _pullTraceEventsFromVmTimeline,
    );

    // Poll for new timeline events.
    // We are polling here instead of listening to the timeline event stream
    // because the event stream is sending out of order and duplicate events.
    // See https://github.com/dart-lang/sdk/issues/46605.
    _pollingTimer = Timer.periodic(timelinePollingInterval, (_) {
      _timelinePollingRateLimiter!.scheduleRequest();
    });
  }

  Future<void> _pullTraceEventsFromVmTimeline({
    bool isInitialPull = false,
  }) async {
    final service = serviceManager.service!;
    final currentVmTime = await service.getVMTimelineMicros();
    debugTraceEventCallback(
      () => log(
        'pulling trace events from '
        '[$_nextPollStartMicros - ${currentVmTime.timestamp}]',
      ),
    );
    final timeline = await service.getVMTimeline(
      timeOriginMicros: _nextPollStartMicros,
      timeExtentMicros: currentVmTime.timestamp! - _nextPollStartMicros,
    );
    _nextPollStartMicros = currentVmTime.timestamp! + 1;

    final threadNameEvents = <TraceEvent>[];
    for (final event in timeline.traceEvents ?? []) {
      final traceEvent = TraceEvent(event.json!);
      final eventWrapper = TraceEventWrapper(
        traceEvent,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (traceEvent.phase == 'M' && traceEvent.name == 'thread_name') {
        threadNameEvents.add(traceEvent);
      }
      allTraceEvents.add(eventWrapper);
      debugTraceEventCallback(() => log(eventWrapper.event.json));
    }

    updateThreadIds(threadNameEvents, isInitialUpdate: isInitialPull);
  }

  void updateThreadIds(
    List<TraceEvent> threadNameEvents, {
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
    for (TraceEvent event in threadNameEvents) {
      final name = event.args!['name'];

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
        log(
          'Could not find UI thread and / or Raster thread from names: '
          '${threadNamesById.values}',
        );
      }

      legacyController.processor.primeThreadIds(
        uiThreadId: uiThreadId,
        rasterThreadId: rasterThreadId,
      );
    }
  }

  FutureOr<void> processAvailableEvents() async {
    assert(!_processing.value);
    _processing.value = true;
    await processTraceEvents(allTraceEvents);
    _processing.value = false;
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

  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents) async {
    if (FeatureFlags.embeddedPerfetto && !useLegacyTraceViewer.value) {
      await perfettoController.loadTrace(traceEvents);
    } else {
      await legacyController.processTraceEvents(
        traceEvents,
        threadNamesById: threadNamesById,
      );
    }
  }

  @override
  void handleSelectedFrame(FlutterFrame frame) async {
    if (useLegacyTraceViewer.value) {
      await _legacySelectFrame(frame);
    } else if (FeatureFlags.embeddedPerfetto) {
      // TODO(kenz): hook up scroll to frame for Perfetto viewer.
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
      log(buf.toString());
    });
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
        await processAvailableEvents();
      }

      if (framesController.currentFrameBeingSelected != frame) return;

      // If the frame is still not well formed after processing all available
      // events, wait a short delay and try to process events again after the
      // VM has been polled one more time.
      if (!frame.isWellFormed && !frameBeforeFirstWellFormedFrame) {
        assert(!_processing.value);
        _processing.value = true;
        await Future.delayed(timelinePollingInterval, () async {
          if (framesController.currentFrameBeingSelected != frame) return;
          await processTraceEvents(allTraceEvents);
          _processing.value = false;
        });
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
    await HttpService.toggleHttpRequestLogging(state);
    _httpTimelineLoggingEnabled.value = state;
  }

  void toggleUseLegacyTraceViewer(bool? value) {
    useLegacyTraceViewer.value = value ?? false;
    // `unawaited` does not work for FutureOr
    // ignore: discarded_futures
    processAvailableEvents();
  }

  void recordTrace(Map<String, dynamic> trace) {
    data!.traceEvents.add(trace);
  }

  void _primeThreadIds(List<TraceEventWrapper> traceEvents) {
    final uiThreadId = _threadIdForEvents({uiEventName}, traceEvents);
    final rasterThreadId = _threadIdForEvents({rasterEventName}, traceEvents);
    legacyController.processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
    // TODO(kenz): prime perfetto processor with thread ids here.
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
        )
    ];
    allTraceEvents
      ..clear()
      ..addAll(traceEvents);
    _primeThreadIds(traceEvents);
    await processAvailableEvents();

    await legacyController.setOfflineData(offlineData);
  }

  @override
  Future<void> clearData() async {
    allTraceEvents.clear();
    _unassignedFlutterFrameEvents.clear();

    threadNamesById.clear();
    _processing.value = false;
    legacyController.clearData();
    if (FeatureFlags.embeddedPerfetto) {
      await perfettoController.clear();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timelinePollingRateLimiter?.dispose();
    legacyController.cpuProfilerController.dispose();
    if (FeatureFlags.embeddedPerfetto) {
      perfettoController.dispose();
    }
    super.dispose();
  }
}

class LegacyTimelineEventsController with SearchControllerMixin<TimelineEvent> {
  LegacyTimelineEventsController(this.performanceController) {
    processor = LegacyTimelineEventProcessor(performanceController);
  }

  final PerformanceController performanceController;

  PerformanceData? get data => performanceController.data;

  late final LegacyTimelineEventProcessor processor;

  /// The currently selected timeline event.
  ValueListenable<TimelineEvent?> get selectedTimelineEvent =>
      _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent?>(null);

  final cpuProfilerController =
      CpuProfilerController(analyticsScreenId: analytics_constants.performance);

  /// The tracking index for the first unprocessed trace event collected.
  int _nextTraceIndexToProcess = 0;

  /// The tracking index for the first unprocessed [TimelineEvent] that needs to
  /// be processed and added to the timeline events flame chart.
  int _nextTimelineEventIndexToProcess = 0;

  void init() {
    unawaited(
      allowedError(
        serviceManager.service!.setProfilePeriod(mediumProfilePeriod),
        logError: false,
      ),
    );
  }

  FutureOr<void> processTraceEvents(
    List<TraceEventWrapper> traceEvents, {
    required Map<int, String> threadNamesById,
  }) async {
    if (debugSimpleTrace) {
      traceEvents = simpleTraceEvents['traceEvents']!
          .where(
            (json) => json.containsKey(TraceEvent.timestampKey),
          ) // thread_name events
          .map(
            (e) => TraceEventWrapper(
              TraceEvent(e),
              DateTime.now().microsecondsSinceEpoch,
            ),
          )
          .toList();
    }

    if (data == null) {
      performanceController.initData();
    }
    final _data = data!;
    final traceEventCount = traceEvents.length;

    debugTraceEventCallback(
      () => log(
        'processing traceEvents at startIndex '
        '$_nextTraceIndexToProcess',
      ),
    );

    final processingTraceCount = traceEventCount - _nextTraceIndexToProcess;

    Future<void> processTraceEventsHelper() async {
      await processor.processTraceEvents(
        traceEvents,
        startIndex: _nextTraceIndexToProcess,
      );
      debugTraceEventCallback(
        () => log(
          'after processing traceEvents at startIndex $_nextTraceIndexToProcess, '
          'and now _nextTraceIndexToProcess = $traceEventCount',
        ),
      );
      _nextTraceIndexToProcess = traceEventCount;

      debugTraceEventCallback(
        () => log(
          'initializing event groups at startIndex '
          '$_nextTimelineEventIndexToProcess',
        ),
      );
      _data.initializeEventGroups(
        threadNamesById,
        startIndex: _nextTimelineEventIndexToProcess,
      );
      debugTraceEventCallback(
        () => log(
          'after initializing event groups at startIndex '
          '$_nextTimelineEventIndexToProcess and now '
          '_nextTimelineEventIndexToProcess = ${_data.timelineEvents.length}',
        ),
      );
      _nextTimelineEventIndexToProcess = _data.timelineEvents.length;
    }

    // Process trace events [processTraceEventsHelper] and time the operation
    // for analytics.
    await ga.timeAsync(
      analytics_constants.performance,
      analytics_constants.traceEventProcessingTime,
      asyncOperation: processTraceEventsHelper,
      screenMetricsProvider: () => PerformanceScreenMetrics(
        traceEventCount: processingTraceCount,
      ),
    );
  }

  Future<void> selectTimelineEvent(
    TimelineEvent? event, {
    bool updateProfiler = true,
  }) async {
    final _data = data!;
    if (event == null || _data.selectedEvent == event) return;

    _data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;

    if (event.isUiEvent && updateProfiler) {
      final storedProfile = cpuProfilerController.cpuProfileStore.lookupProfile(
        time: event.time,
      );
      if (storedProfile != null) {
        await cpuProfilerController.processAndSetData(
          storedProfile,
          processId: 'Stored profile for ${event.time}',
          storeAsUserTagNone: true,
          shouldApplyFilters: true,
          shouldRefreshSearchMatches: true,
        );
        _data.cpuProfileData = cpuProfilerController.dataNotifier.value;
      } else if ((!offlineController.offlineMode.value ||
              performanceController.offlinePerformanceData == null) &&
          cpuProfilerController.profilerEnabled) {
        // Fetch a profile if not in offline mode and if the profiler is enabled
        cpuProfilerController.reset();
        await cpuProfilerController.pullAndProcessProfile(
          startMicros: event.time.start!.inMicroseconds,
          extentMicros: event.time.duration.inMicroseconds,
          processId: '${event.traceEvents.first.wrapperId}',
        );
        _data.cpuProfileData = cpuProfilerController.dataNotifier.value;
      }
    }
  }

  Future<void> updateCpuProfileForFrame(FlutterFrame frame) async {
    final storedProfileForFrame =
        cpuProfilerController.cpuProfileStore.lookupProfile(
      time: frame.timeFromEventFlows,
    );
    if (storedProfileForFrame == null) {
      cpuProfilerController.reset();
      if (!offlineController.offlineMode.value &&
          frame.timeFromEventFlows.isWellFormed) {
        await cpuProfilerController.pullAndProcessProfile(
          startMicros: frame.timeFromEventFlows.start!.inMicroseconds,
          extentMicros: frame.timeFromEventFlows.duration.inMicroseconds,
          processId: 'Flutter frame ${frame.id}',
        );
      }
      if (performanceController
              .flutterFramesController.currentFrameBeingSelected !=
          frame) return;
      data?.cpuProfileData = cpuProfilerController.dataNotifier.value;
    } else {
      if (!storedProfileForFrame.processed) {
        await storedProfileForFrame.process(
          transformer: cpuProfilerController.transformer,
          processId: 'Flutter frame ${frame.id} - stored profile ',
        );
      }
      if (performanceController
              .flutterFramesController.currentFrameBeingSelected !=
          frame) return;
      data?.cpuProfileData = storedProfileForFrame.getActive(
        cpuProfilerController.viewType.value,
      );
      cpuProfilerController.loadProcessedData(
        storedProfileForFrame,
        storeAsUserTagNone: true,
      );
    }
  }

  @override
  List<TimelineEvent> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    if (search.isEmpty) return <TimelineEvent>[];
    final matches = <TimelineEvent>[];
    if (searchPreviousMatches) {
      final List<TimelineEvent> previousMatches = searchMatches.value;
      for (final previousMatch in previousMatches) {
        if (previousMatch.name!.caseInsensitiveContains(search)) {
          matches.add(previousMatch);
        }
      }
    } else {
      final events = List<TimelineEvent>.from(data!.timelineEvents);
      for (final event in events) {
        breadthFirstTraversal<TimelineEvent>(
          event,
          action: (TimelineEvent e) {
            if (e.name!.caseInsensitiveContains(search)) {
              matches.add(e);
            }
          },
        );
      }
    }
    return matches;
  }

  Future<void> setOfflineData(PerformanceData offlineData) async {
    if (offlineData.cpuProfileData != null) {
      await cpuProfilerController.transformer.processData(
        offlineData.cpuProfileData!,
        processId: 'process offline data',
      );
    }

    if (offlineData.selectedEvent != null) {
      for (var timelineEvent in data!.timelineEvents) {
        final eventToSelect = timelineEvent.firstChildWithCondition((event) {
          return event.name == offlineData.selectedEvent!.name &&
              event.time == offlineData.selectedEvent!.time;
        });
        if (eventToSelect != null) {
          data!
            ..selectedEvent = eventToSelect
            ..cpuProfileData = offlineData.cpuProfileData;
          _selectedTimelineEventNotifier.value = eventToSelect;
          break;
        }
      }
    }

    final offlineCpuProfileData = offlineData.cpuProfileData;
    if (offlineCpuProfileData != null) {
      cpuProfilerController.loadProcessedData(
        CpuProfilePair(
          functionProfile: offlineCpuProfileData,
          // TODO(bkonyi): do we care about offline code profiles?
          codeProfile: null,
        ),
        storeAsUserTagNone: true,
      );
    }
  }

  void clearData() {
    cpuProfilerController.reset();
    processor.reset();
    _nextTraceIndexToProcess = 0;
    _nextTimelineEventIndexToProcess = 0;
    _selectedTimelineEventNotifier.value = null;
  }
}
