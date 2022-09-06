// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart' show Event;

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/import_export/import_export.dart';
import '../../config_specific/logger/allowed_error.dart';
import '../../config_specific/logger/logger.dart';
import '../../http/http_service.dart';
import '../../primitives/auto_dispose.dart';
import '../../primitives/trace_event.dart';
import '../../primitives/trees.dart';
import '../../primitives/utils.dart';
import '../../service/service_manager.dart';
import '../../shared/globals.dart';
import '../../ui/search.dart';
import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../profiler/profile_granularity.dart';
import 'panes/controls/enhance_tracing/enhance_tracing_controller.dart';
import 'panes/raster_metrics/raster_metrics_controller.dart';
import 'panes/timeline_events/perfetto/perfetto.dart';
import 'performance_model.dart';
import 'performance_screen.dart';
import 'performance_utils.dart';
import 'rebuild_counts.dart';
import 'simple_trace_example.dart';
import 'timeline_event_processor.dart';

/// Debugging flag to load sample trace events from [simple_trace_example.dart].
bool debugSimpleTrace = false;

/// Flag to enable the embedded perfetto trace viewer.
bool embeddedPerfettoEnabled = false;

/// Flag to hide the frame analysis feature while it is under development.
bool frameAnalysisSupported = true;

/// Flag to hide the raster metrics feature while it is under development.
bool rasterMetricsSupported = true;

/// This class contains the business logic for [performance_screen.dart].
///
/// The controller manages the timeline data model and communicates with the
/// view to give and receive data updates. It also manages data processing via
/// [TimelineEventProcessor] and [CpuProfileTransformer].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class PerformanceController extends DisposableController
    with SearchControllerMixin<TimelineEvent>, AutoDisposeControllerMixin {
  PerformanceController() {
    processor = TimelineEventProcessor(this);
    _init();
  }

  final cpuProfilerController =
      CpuProfilerController(analyticsScreenId: analytics_constants.performance);

  final enhanceTracingController = EnhanceTracingController();

  final rasterMetricsController = RasterMetricsController();

  final perfettoController = createPerfettoController();

  final _exportController = ExportController();

  /// The currently selected timeline event.
  ValueListenable<TimelineEvent?> get selectedTimelineEvent =>
      _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent?>(null);

  /// The currently selected timeline frame.
  ValueListenable<FlutterFrame?> get selectedFrame => _selectedFrameNotifier;
  final _selectedFrameNotifier = ValueNotifier<FlutterFrame?>(null);

  /// The flutter frames in the current timeline.
  ValueListenable<List<FlutterFrame>> get flutterFrames => _flutterFrames;
  final _flutterFrames = ListValueNotifier<FlutterFrame>([]);

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

  ValueListenable<bool> get badgeTabForJankyFrames => _badgeTabForJankyFrames;
  final _badgeTabForJankyFrames = ValueNotifier<bool>(false);

  final threadNamesById = <int, String>{};

  /// Active timeline data.
  ///
  /// This is the true source of data for the UI. In the case of an offline
  /// import, this will begin as a copy of [offlinePerformanceData] (the original
  /// data from the imported file). If any modifications are made while the data
  /// is displayed (e.g. change in selected timeline event, selected frame,
  /// etc.), those changes will be tracked here.
  PerformanceData? data;

  /// Timeline data loaded via import.
  ///
  /// This is expected to be null when we are not in [offlineController.offlineMode].
  ///
  /// This will contain the original data from the imported file, regardless of
  /// any selection modifications that occur while the data is displayed. [data]
  /// will start as a copy of offlineTimelineData in this case, and will track
  /// any data modifications that occur while the data is displayed (e.g. change
  /// in selected timeline event, selected frame, etc.).
  PerformanceData? offlinePerformanceData;

  late final TimelineEventProcessor processor;

  /// Trace events in the current timeline.
  ///
  /// This list is cleared and repopulated each time "Refresh" is clicked.
  final allTraceEvents = <TraceEventWrapper>[];

  /// The tracking index for the first unprocessed trace event collected.
  int _nextTraceIndexToProcess = 0;

  /// The tracking index for the first unprocessed [TimelineEvent] that needs to
  /// be processed and added to the timeline events flame chart.
  int _nextTimelineEventIndexToProcess = 0;

  /// Whether flutter frames are currently being recorded.
  ValueListenable<bool> get recordingFrames => _recordingFrames;
  final _recordingFrames = ValueNotifier<bool>(true);

  /// Frames that have been recorded but not shown because the flutter frame
  /// recording has been paused.
  final _pendingFlutterFrames = <FlutterFrame>[];

  /// The collection of [TimelineEvent]s that should be linked to
  /// [FlutterFrame]s but have not yet been assigned.
  ///
  /// These timeline events are keyed by the [FlutterFrame] ID specified in the
  /// event arguments, which matches the ID for the corresponding
  /// [FlutterFrame].
  final _unassignedFlutterFrameEvents = <int, FrameTimelineEventData>{};

  /// The collection of Flutter frames that have not yet been linked to their
  /// respective [TimelineEvent]s for the UI and Raster thread.
  ///
  /// These [FlutterFrame]s are keyed by the Flutter frame ID that matches the
  /// frame id in the corresponding [TimelineEvent]s.
  final _unassignedFlutterFrames = <int, FlutterFrame>{};

  final RebuildCountModel rebuildCountModel = RebuildCountModel();

  Timer? _pollingTimer;

  int _nextPollStartMicros = 0;

  static const timelinePollingRateLimit = 5.0;

  static const timelinePollingInterval = Duration(seconds: 1);

  RateLimiter? _timelinePollingRateLimiter;

  late final Future<void> _initialized;

  Future<void> get initialized => _initialized;

  Future<void> _init() {
    return _initialized = _initHelper();
  }

  Future<void> _initHelper() async {
    if (embeddedPerfettoEnabled) {
      perfettoController.init();
    }

    if (!offlineController.offlineMode.value) {
      await serviceManager.onServiceAvailable;
      await _initData();

      // Default to true for profile builds only.
      _badgeTabForJankyFrames.value =
          await serviceManager.connectedApp!.isProfileBuild;

      unawaited(
        allowedError(
          serviceManager.service!.setProfilePeriod(mediumProfilePeriod),
          logError: false,
        ),
      );
      await serviceManager.timelineStreamManager.setDefaultTimelineStreams();
      await toggleHttpRequestLogging(true);

      // Initialize displayRefreshRate.
      _displayRefreshRate.value =
          await serviceManager.queryDisplayRefreshRate ?? defaultRefreshRate;
      data?.displayRefreshRate = _displayRefreshRate.value;

      enhanceTracingController.init();

      // Listen for the first 'Flutter.Frame' event we receive from this point
      // on so that we know the start id for frames that we can assign the
      // current [FlutterFrame.enhanceTracingState].
      _listenForFirstLiveFrame();

      // Listen for Flutter.Frame events with frame timing data.
      // Listen for Flutter.RebuiltWidgets events.
      autoDisposeStreamSubscription(
        serviceManager.service!.onExtensionEventWithHistory.listen((event) {
          if (event.extensionKind == 'Flutter.Frame') {
            final frame = FlutterFrame.parse(event.extensionData!.data);
            // We can only assign [FlutterFrame.enhanceTracingState] for frames
            // with ids after [_firstLiveFrameId].
            if (_firstLiveFrameId != null && frame.id >= _firstLiveFrameId!) {
              frame.enhanceTracingState = enhanceTracingController.tracingState;
            }
            addFrame(frame);
          } else if (event.extensionKind == 'Flutter.RebuiltWidgets') {
            rebuildCountModel.processRebuildEvent(event.extensionData!.data);
          }
        }),
      );

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
  }

  Future<void> _initData() async {
    final connectedApp = serviceManager.connectedApp!;
    await connectedApp.initialized.future;
    data = connectedApp.isFlutterAppNow!
        ? PerformanceData(
            displayRefreshRate: await serviceManager.queryDisplayRefreshRate,
          )
        : PerformanceData();
  }

  /// The id of the first 'Flutter.Frame' event that occurs after the DevTools
  /// performance page is opened.
  ///
  /// For frames with this id and greater, we can assign
  /// [FlutterFrame.enhanceTracingState]. For frames with an earlier id, we
  /// do not know the value of [FlutterFrame.enhanceTracingState], and we will
  /// use other heuristics.
  int? _firstLiveFrameId;

  /// Stream subscription on the 'Extension' stream that listens for the first
  /// 'Flutter.Frame' event.
  ///
  /// This stream should be initialized and cancelled in
  /// [_listenForFirstLiveFrame], unless we never receive any 'Flutter.Frame'
  /// events, in which case the subscription will be canceled in [dispose].
  StreamSubscription<Event>? _firstFrameEventSubscription;

  /// Listens on the 'Extension' stream (without history) for 'Flutter.Frame'
  /// events.
  ///
  /// This method assigns [_firstLiveFrameId] when the first 'Flutter.Frame'
  /// event is received, and then cancels the stream subscription.
  void _listenForFirstLiveFrame() {
    _firstFrameEventSubscription =
        serviceManager.service!.onExtensionEvent.listen(
      (event) {
        if (event.extensionKind == 'Flutter.Frame' &&
            _firstLiveFrameId == null) {
          _firstLiveFrameId = FlutterFrame.parse(event.extensionData!.data).id;
          _firstFrameEventSubscription!.cancel();
          _firstFrameEventSubscription = null;
        }
      },
    );
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
    final _data = data!;
    if (event == null || _data.selectedEvent == event) return;

    _data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;

    if (event.isUiEvent && updateProfiler) {
      final storedProfile =
          cpuProfilerController.cpuProfileStore.lookupProfile(time: event.time);
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
              offlinePerformanceData == null) &&
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

  ValueListenable<double> get displayRefreshRate => _displayRefreshRate;
  final _displayRefreshRate = ValueNotifier<double>(defaultRefreshRate);

  /// Tracks the current frame undergoing selection so that we can equality
  /// check after async operations and bail out early if another frame has been
  /// selected during awaits.
  FlutterFrame? _currentFrameBeingSelected;

  Future<void> toggleSelectedFrame(FlutterFrame frame) async {
    if (data == null) {
      return;
    }
    final _data = data!;

    _currentFrameBeingSelected = frame;

    // Unselect [frame] if is already selected.
    if (_data.selectedFrame == frame) {
      _data.selectedFrame = null;
      _selectedFrameNotifier.value = null;
      return;
    }

    _data.selectedFrame = frame;
    _selectedFrameNotifier.value = frame;

    if (!offlineController.offlineMode.value) {
      final bool frameBeforeFirstWellFormedFrame =
          firstWellFormedFrameMicros != null &&
              frame.timeFromFrameTiming.start!.inMicroseconds <
                  firstWellFormedFrameMicros!;
      if (!frame.isWellFormed && !frameBeforeFirstWellFormedFrame) {
        // Only try to pull timeline events for frames that are after the first
        // well formed frame. Timeline events that occurred before this frame will
        // have already fallen out of the buffer.
        await processAvailableEvents();
      }

      if (_currentFrameBeingSelected != frame) return;

      // If the frame is still not well formed after processing all available
      // events, wait a short delay and try to process events again after the
      // VM has been polled one more time.
      if (!frame.isWellFormed && !frameBeforeFirstWellFormedFrame) {
        assert(!_processing.value);
        _processing.value = true;
        await Future.delayed(timelinePollingInterval, () async {
          if (_currentFrameBeingSelected != frame) return;
          await processTraceEvents(allTraceEvents);
          _processing.value = false;
        });
      }

      if (_currentFrameBeingSelected != frame) return;
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

    if (_currentFrameBeingSelected != frame) return;

    final storedProfileForFrame = cpuProfilerController.cpuProfileStore
        .lookupProfile(time: frame.timeFromEventFlows);
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
      if (_currentFrameBeingSelected != frame) return;
      _data.cpuProfileData = cpuProfilerController.dataNotifier.value;
    } else {
      if (!storedProfileForFrame.processed) {
        await cpuProfilerController.transformer.processData(
          storedProfileForFrame,
          processId: 'Flutter frame ${frame.id} - stored profile ',
        );
      }
      if (_currentFrameBeingSelected != frame) return;
      _data.cpuProfileData = storedProfileForFrame;
      cpuProfilerController.loadProcessedData(
        storedProfileForFrame,
        storeAsUserTagNone: true,
      );
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

  void addFrame(FlutterFrame frame) {
    _assignEventsToFrame(frame);
    if (_recordingFrames.value) {
      if (_pendingFlutterFrames.isNotEmpty) {
        _addPendingFlutterFrames();
      }
      _maybeBadgeTabForJankyFrame(frame);
      data!.frames.add(frame);
      _flutterFrames.add(frame);
    } else {
      _pendingFlutterFrames.add(frame);
    }
  }

  /// Timestamp in micros of the first well formed frame, or in other words,
  /// the first frame for which we have timeline event data.
  int? firstWellFormedFrameMicros;

  void _updateFirstWellFormedFrameMicros(FlutterFrame frame) {
    assert(frame.isWellFormed);
    firstWellFormedFrameMicros = math.min(
      firstWellFormedFrameMicros ?? maxJsInt,
      frame.timeFromFrameTiming.start!.inMicroseconds,
    );
  }

  void _assignEventsToFrame(FlutterFrame frame) {
    if (_unassignedFlutterFrameEvents.containsKey(frame.id)) {
      _maybeAddUnassignedEventsToFrame(frame);
    }
    if (frame.isWellFormed) {
      _updateFirstWellFormedFrameMicros(frame);
    } else {
      _unassignedFlutterFrames[frame.id] = frame;
    }
  }

  void _maybeAddUnassignedEventsToFrame(FlutterFrame frame) {
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
    final event = _unassignedFlutterFrameEvents[frame.id]!.eventByType(type);
    if (event != null) {
      frame.setEventFlow(event, type: type);
    }
  }

  void _maybeAddEventToUnassignedFrame(
    int? frameNumber,
    SyncTimelineEvent event,
    TimelineEventType type,
  ) {
    if (frameNumber != null && (event.isUiEvent || event.isRasterEvent)) {
      if (_unassignedFlutterFrames.containsKey(frameNumber)) {
        final frame = _unassignedFlutterFrames[frameNumber]!;
        frame.setEventFlow(event, type: type);
        if (frame.isWellFormed) {
          _unassignedFlutterFrames.remove(frameNumber);
          _updateFirstWellFormedFrameMicros(frame);
        }
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

  void _addPendingFlutterFrames() {
    _pendingFlutterFrames.forEach(_maybeBadgeTabForJankyFrame);
    data!.frames.addAll(_pendingFlutterFrames);
    _flutterFrames.addAll(_pendingFlutterFrames);
    _pendingFlutterFrames.clear();
  }

  void _maybeBadgeTabForJankyFrame(FlutterFrame frame) {
    if (_badgeTabForJankyFrames.value) {
      if (frame.isJanky(_displayRefreshRate.value)) {
        serviceManager.errorBadgeManager
            .incrementBadgeCount(PerformanceScreen.id);
      }
    }
  }

  void toggleRecordingFrames(bool recording) {
    _recordingFrames.value = recording;
    if (recording) {
      _addPendingFlutterFrames();
    }
  }

  void updateThreadIds(
    List<TraceEvent> threadNameEvents, {
    bool isInitialUpdate = false,
  }) {
    final isFlutterApp = offlineController.offlineMode.value
        ? offlinePerformanceData != null &&
            offlinePerformanceData!.frames.isNotEmpty
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

      processor.primeThreadIds(
        uiThreadId: uiThreadId,
        rasterThreadId: rasterThreadId,
      );
    }
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

  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents) async {
    if (embeddedPerfettoEnabled) {
      await perfettoController.loadTrace(traceEvents);
    } else {
      await _processTraceEvents(traceEvents);
    }
  }

  FutureOr<void> _processTraceEvents(
    List<TraceEventWrapper> traceEvents,
  ) async {
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
      await _initData();
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

  FutureOr<void> processOfflineData(OfflinePerformanceData offlineData) async {
    await clearData();
    final traceEvents = [
      for (var trace in offlineData.traceEvents)
        TraceEventWrapper(
          TraceEvent(trace),
          DateTime.now().microsecondsSinceEpoch,
        )
    ];

    // TODO(kenz): once each trace event has a ui/raster distinction bit added to
    // the trace, we will not need to infer thread ids. This is not robust.
    final uiThreadId = _threadIdForEvents({uiEventName}, traceEvents);
    final rasterThreadId = _threadIdForEvents({rasterEventName}, traceEvents);

    offlinePerformanceData = offlineData.shallowClone();
    data = offlineData.shallowClone();

    // Process offline data.
    processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
    await processTraceEvents(traceEvents);
    if (data!.cpuProfileData != null) {
      await cpuProfilerController.transformer.processData(
        offlinePerformanceData!.cpuProfileData!,
        processId: 'process offline data',
      );
    }

    offlinePerformanceData!.frames.forEach(_assignEventsToFrame);

    // Set offline data.
    setOfflineData();
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

  void setOfflineData() {
    final _data = data!;
    final _offlineData = offlinePerformanceData!;
    _flutterFrames
      ..clear()
      ..addAll(_offlineData.frames);
    final frameToSelect = _offlineData.frames.firstWhereOrNull(
      (frame) => frame.id == _offlineData.selectedFrameId,
    );
    if (frameToSelect != null) {
      _data.selectedFrame = frameToSelect;
      _selectedFrameNotifier.value = frameToSelect;
    }
    if (_offlineData.selectedEvent != null) {
      for (var timelineEvent in _data.timelineEvents) {
        final eventToSelect = timelineEvent.firstChildWithCondition((event) {
          return event.name == _offlineData.selectedEvent!.name &&
              event.time == _offlineData.selectedEvent!.time;
        });
        if (eventToSelect != null) {
          _data
            ..selectedEvent = eventToSelect
            ..cpuProfileData = _offlineData.cpuProfileData;
          _selectedTimelineEventNotifier.value = eventToSelect;
          break;
        }
      }
    }

    if (_offlineData.cpuProfileData != null) {
      cpuProfilerController.loadProcessedData(
        _offlineData.cpuProfileData!,
        storeAsUserTagNone: true,
      );
    }

    _displayRefreshRate.value = _offlineData.displayRefreshRate;
  }

  /// Exports the current timeline data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData =
        _exportController.encode(PerformanceScreen.id, data!.json);
    return _exportController.downloadFile(encodedData);
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

  Future<void> toggleHttpRequestLogging(bool state) async {
    await HttpService.toggleHttpRequestLogging(state);
    _httpTimelineLoggingEnabled.value = state;
  }

  /// Clears the timeline data currently stored by the controller as well the
  /// VM timeline if a connected app is present.
  Future<void> clearData() async {
    if (serviceManager.connectedAppInitialized) {
      await serviceManager.service!.clearVMTimeline();
    }
    allTraceEvents.clear();
    offlinePerformanceData = null;
    cpuProfilerController.reset();
    threadNamesById.clear();
    data?.clear();
    processor.reset();
    _flutterFrames.clear();
    _nextTraceIndexToProcess = 0;
    _nextTimelineEventIndexToProcess = 0;
    _unassignedFlutterFrameEvents.clear();
    _unassignedFlutterFrames.clear();
    firstWellFormedFrameMicros = null;
    _selectedTimelineEventNotifier.value = null;
    _selectedFrameNotifier.value = null;
    _processing.value = false;
    serviceManager.errorBadgeManager.clearErrors(PerformanceScreen.id);
    if (embeddedPerfettoEnabled) {
      await perfettoController.clear();
    }
  }

  void recordTrace(Map<String, dynamic> trace) {
    data!.traceEvents.add(trace);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timelinePollingRateLimiter?.dispose();
    cpuProfilerController.dispose();
    if (embeddedPerfettoEnabled) {
      perfettoController.dispose();
    }
    enhanceTracingController.dispose();
    _firstFrameEventSubscription?.cancel();
    super.dispose();
  }
}
