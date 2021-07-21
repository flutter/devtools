// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../auto_dispose.dart';
import '../config_specific/import_export/import_export.dart';
import '../config_specific/logger/allowed_error.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../http/http_service.dart';
import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../profiler/profile_granularity.dart';
import '../service_manager.dart';
import '../trace_event.dart';
import '../trees.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'performance_model.dart';
import 'performance_screen.dart';
import 'performance_utils.dart';
import 'timeline_event_processor.dart';
import 'timeline_streams.dart';

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
    with
        CpuProfilerControllerProviderMixin,
        SearchControllerMixin<TimelineEvent>,
        AutoDisposeControllerMixin {
  PerformanceController() {
    processor = TimelineEventProcessor(this);
    _init();
  }

  final _exportController = ExportController();

  /// The currently selected timeline event.
  ValueListenable<TimelineEvent> get selectedTimelineEvent =>
      _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent>(null);

  /// The currently selected timeline frame.
  ValueListenable<FlutterFrame> get selectedFrame => _selectedFrameNotifier;
  final _selectedFrameNotifier = ValueNotifier<FlutterFrame>(null);

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

  // TODO(kenz): switch to use VmFlagManager-like pattern once
  // https://github.com/dart-lang/sdk/issues/41822 is fixed.
  /// Recorded timeline stream values.
  final recordedStreams = [
    dartTimelineStream,
    embedderTimelineStream,
    gcTimelineStream,
    apiTimelineStream,
    compilerTimelineStream,
    compilerVerboseTimelineStream,
    debuggerTimelineStream,
    isolateTimelineStream,
    vmTimelineStream,
  ];

  final threadNamesById = <int, String>{};

  /// Active timeline data.
  ///
  /// This is the true source of data for the UI. In the case of an offline
  /// import, this will begin as a copy of [offlinePerformanceData] (the original
  /// data from the imported file). If any modifications are made while the data
  /// is displayed (e.g. change in selected timeline event, selected frame,
  /// etc.), those changes will be tracked here.
  PerformanceData data;

  /// Timeline data loaded via import.
  ///
  /// This is expected to be null when we are not in [offlineMode].
  ///
  /// This will contain the original data from the imported file, regardless of
  /// any selection modifications that occur while the data is displayed. [data]
  /// will start as a copy of offlineTimelineData in this case, and will track
  /// any data modifications that occur while the data is displayed (e.g. change
  /// in selected timeline event, selected frame, etc.).
  PerformanceData offlinePerformanceData;

  TimelineEventProcessor processor;

  /// Trace events in the current timeline.
  ///
  /// This list is cleared and repopulated each time "Refresh" is clicked.
  List<TraceEventWrapper> allTraceEvents = [];

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

  Timer _pollingTimer;

  int _nextPollStartMicros = 0;

  static const timelinePollingRateLimit = 5.0;

  static const timelinePollingInterval = Duration(seconds: 1);

  RateLimiter _timelinePollingRateLimiter;

  Future<void> _initialized;
  Future<void> get initialized => _initialized;

  Future<void> _init() {
    return _initialized = _initHelper();
  }

  Future<void> _initHelper() async {
    if (!offlineMode) {
      await serviceManager.onServiceAvailable;
      await _initData();

      // Default to true for profile builds only.
      _badgeTabForJankyFrames.value =
          await serviceManager.connectedApp.isProfileBuild;

      unawaited(allowedError(
        serviceManager.service.setProfilePeriod(mediumProfilePeriod),
        logError: false,
      ));
      await setTimelineStreams([
        dartTimelineStream,
        embedderTimelineStream,
        gcTimelineStream,
      ]);
      await toggleHttpRequestLogging(true);

      // Initialize displayRefreshRate.
      _displayRefreshRate.value =
          await serviceManager.queryDisplayRefreshRate ?? defaultRefreshRate;
      data?.displayRefreshRate = _displayRefreshRate.value;

      // Listen for Flutter.Frame events with frame timing data.
      autoDispose(
          serviceManager.service.onExtensionEventWithHistory.listen((event) {
        if (event.extensionKind == 'Flutter.Frame') {
          final frame = FlutterFrame.parse(event.extensionData.data);
          addFrame(frame);
        }
      }));

      // Load available timeline events.
      await _pullTraceEventsFromVmTimeline(shouldPrimeThreadIds: true);

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
        _timelinePollingRateLimiter.scheduleRequest();
      });
    }
  }

  Future<void> _initData() async {
    data = serviceManager.connectedApp.isFlutterAppNow
        ? PerformanceData(
            displayRefreshRate: await serviceManager.queryDisplayRefreshRate,
          )
        : PerformanceData();
  }

  Future<void> _pullTraceEventsFromVmTimeline({
    bool shouldPrimeThreadIds = false,
  }) async {
    final currentVmTime = await serviceManager.service.getVMTimelineMicros();
    debugTraceEventCallback(
      () => log(
        'pulling trace events from '
        '[$_nextPollStartMicros - ${currentVmTime.timestamp}]',
      ),
    );
    final timeline = await serviceManager.service.getVMTimeline(
      timeOriginMicros: _nextPollStartMicros,
      timeExtentMicros: currentVmTime.timestamp - _nextPollStartMicros,
    );
    _nextPollStartMicros = currentVmTime.timestamp + 1;

    // TODO(kenz): move this priming logic into the loop below.
    if (shouldPrimeThreadIds) primeThreadIds(timeline);
    for (final event in timeline.traceEvents) {
      final eventWrapper = TraceEventWrapper(
        TraceEvent(event.json),
        DateTime.now().millisecondsSinceEpoch,
      );
      allTraceEvents.add(eventWrapper);
      debugTraceEventCallback(() => log(eventWrapper.event.json));
    }
  }

  FutureOr<void> processAvailableEvents() async {
    assert(!_processing.value);
    _processing.value = true;
    await processTraceEvents(allTraceEvents);
    _processing.value = false;
  }

  Future<void> selectTimelineEvent(
    TimelineEvent event, {
    bool updateProfiler = true,
  }) async {
    if (event == null || data.selectedEvent == event) return;

    data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;

    if (event.isUiEvent && updateProfiler) {
      final storedProfile =
          cpuProfilerController.cpuProfileStore.lookupProfile(event.time);
      if (storedProfile != null) {
        await cpuProfilerController.processAndSetData(
          storedProfile,
          processId: 'Stored profile for ${event.time}',
        );
        data.cpuProfileData = cpuProfilerController.dataNotifier.value;
      } else if ((!offlineMode || offlinePerformanceData == null) &&
          cpuProfilerController.profilerEnabled) {
        // Fetch a profile if not in offline mode and if the profiler is enabled
        cpuProfilerController.reset();
        await cpuProfilerController.pullAndProcessProfile(
          startMicros: event.time.start.inMicroseconds,
          extentMicros: event.time.duration.inMicroseconds,
          processId: '${event.traceEvents.first.wrapperId}',
        );
        data.cpuProfileData = cpuProfilerController.dataNotifier.value;
      }
    }
  }

  ValueListenable<double> get displayRefreshRate => _displayRefreshRate;
  final _displayRefreshRate = ValueNotifier<double>(defaultRefreshRate);

  /// Tracks the current frame undergoing selection so that we can equality
  /// check after async operations and bail out early if another frame has been
  /// selected during awaits.
  FlutterFrame _currentFrameBeingSelected;

  Future<void> toggleSelectedFrame(FlutterFrame frame) async {
    if (frame == null || data == null) {
      return;
    }

    _currentFrameBeingSelected = frame;

    // Unselect [frame] if is already selected.
    if (data.selectedFrame == frame) {
      data.selectedFrame = null;
      _selectedFrameNotifier.value = null;
      return;
    }

    final bool frameBeforeFirstWellFormedFrame =
        firstWellFormedFrameMicros != null &&
            frame.timeFromFrameTiming.start.inMicroseconds <
                firstWellFormedFrameMicros;
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

    data.selectedFrame = frame;
    _selectedFrameNotifier.value = frame;

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
        .lookupProfile(frame.timeFromEventFlows);
    if (storedProfileForFrame == null) {
      cpuProfilerController.reset();
      if (!offlineMode && frame.timeFromEventFlows.isWellFormed) {
        await cpuProfilerController.pullAndProcessProfile(
          startMicros: frame.timeFromEventFlows.start.inMicroseconds,
          extentMicros: frame.timeFromEventFlows.duration.inMicroseconds,
          processId: 'Flutter frame ${frame.id}',
        );
      }
      if (_currentFrameBeingSelected != frame) return;
      data.cpuProfileData = cpuProfilerController.dataNotifier.value;
    } else {
      if (!storedProfileForFrame.processed) {
        await cpuProfilerController.transformer.processData(
          storedProfileForFrame,
          processId: 'Flutter frame ${frame.id} - stored profile ',
        );
      }
      if (_currentFrameBeingSelected != frame) return;
      data.cpuProfileData = storedProfileForFrame;
      cpuProfilerController.loadProcessedData(storedProfileForFrame);
    }

    if (debugTimeline) {
      final buf = StringBuffer();
      buf.writeln('UI timeline event for frame ${frame.id}:');
      frame.timelineEventData.uiEvent.format(buf, '  ');
      buf.writeln('\nUI trace for frame ${frame.id}');
      frame.timelineEventData.uiEvent.writeTraceToBuffer(buf);
      buf.writeln('\Raster timeline event frame ${frame.id}:');
      frame.timelineEventData.rasterEvent.format(buf, '  ');
      buf.writeln('\nRaster trace for frame ${frame.id}');
      frame.timelineEventData.rasterEvent.writeTraceToBuffer(buf);
      log(buf.toString());
    }
  }

  void addFrame(FlutterFrame frame) {
    assignEventsToFrame(frame);
    if (_recordingFrames.value) {
      if (_pendingFlutterFrames.isNotEmpty) {
        _addPendingFlutterFrames();
      }
      _maybeBadgeTabForJankyFrame(frame);
      data.frames.add(frame);
      _flutterFrames.add(frame);
    } else {
      _pendingFlutterFrames.add(frame);
    }
  }

  /// Timestamp in micros of the first well formed frame, or in other words,
  /// the first frame for which we have timeline event data.
  int firstWellFormedFrameMicros;

  void _updateFirstWellFormedFrameMicros(FlutterFrame frame) {
    assert(frame.isWellFormed);
    firstWellFormedFrameMicros = math.min(
      firstWellFormedFrameMicros ?? maxJsInt,
      frame.timeFromFrameTiming.start.inMicroseconds,
    );
  }

  void assignEventsToFrame(FlutterFrame frame) {
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
    final event = _unassignedFlutterFrameEvents[frame.id].eventByType(type);
    if (event != null) {
      frame.setEventFlow(event, type: type);
    }
  }

  void _maybeAddEventToUnassignedFrame(
    int frameNumber,
    TimelineEvent event,
    TimelineEventType type,
  ) {
    if (frameNumber != null && (event.isUiEvent || event.isRasterEvent)) {
      if (_unassignedFlutterFrames.containsKey(frameNumber)) {
        final frame = _unassignedFlutterFrames[frameNumber];
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
    data.frames.addAll(_pendingFlutterFrames);
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

  void primeThreadIds(vm_service.Timeline timeline) {
    threadNamesById.clear();
    final threadNameEvents = timeline.traceEvents
        .map((event) => TraceEvent(event.json))
        .where((TraceEvent event) {
      return event.phase == 'M' && event.name == 'thread_name';
    }).toList();

    // TODO(kenz): Remove this logic once ui/raster distinction changes are
    // available in the engine.
    int uiThreadId;
    int rasterThreadId;
    for (TraceEvent event in threadNameEvents) {
      final name = event.args['name'];

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
        // MacOS and Flutter apps with platform views do not have a .gpu thread.
        // In these cases, the "Raster" events will come on the .platform thread
        // instead.
        rasterThreadId ??= event.threadId;
      }

      threadNamesById[event.threadId] = name;
    }

    if (uiThreadId == null || rasterThreadId == null) {
      log('Could not find UI thread and / or Raster thread from names: '
          '${threadNamesById.values}');
    }

    processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
  }

  void addTimelineEvent(TimelineEvent event) {
    data.addTimelineEvent(event);
    if (event is SyncTimelineEvent) {
      if (!offlineMode &&
          serviceManager.hasConnection &&
          !serviceManager.connectedApp.isFlutterAppNow) {
        return;
      }
      _maybeAddEventToUnassignedFrame(
        event.uiFrameNumber,
        event,
        TimelineEventType.ui,
      );
      _maybeAddEventToUnassignedFrame(
        event.rasterFrameNumber,
        event,
        TimelineEventType.raster,
      );
    }
  }

  FutureOr<void> processTraceEvents(
    List<TraceEventWrapper> traceEvents, {
    int startIndex = 0,
  }) async {
    if (data == null) {
      await _initData();
    }
    final traceEventCount = traceEvents.length;

    debugTraceEventCallback(
      () => log(
        'processing traceEvents at startIndex '
        '$_nextTraceIndexToProcess',
      ),
    );
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
    data.initializeEventGroups(
      threadNamesById,
      startIndex: _nextTimelineEventIndexToProcess,
    );
    debugTraceEventCallback(
      () => log(
        'after initializing event groups at startIndex '
        '$_nextTimelineEventIndexToProcess and now '
        '_nextTimelineEventIndexToProcess = ${data.timelineEvents.length}',
      ),
    );
    _nextTimelineEventIndexToProcess = data.timelineEvents.length;
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
    if (data.cpuProfileData != null) {
      await cpuProfilerController.transformer
          .processData(offlinePerformanceData.cpuProfileData);
    }

    offlinePerformanceData.frames.forEach(assignEventsToFrame);

    // Set offline data.
    setOfflineData();
  }

  int _threadIdForEvents(
    Set<String> targetEventNames,
    List<TraceEventWrapper> traceEvents,
  ) {
    const invalidThreadId = -1;
    return traceEvents
            .firstWhere(
              (trace) => targetEventNames.contains(trace.event.name),
              orElse: () => null,
            )
            ?.event
            ?.threadId ??
        invalidThreadId;
  }

  void setOfflineData() {
    _flutterFrames
      ..clear()
      ..addAll(offlinePerformanceData.frames);
    final frameToSelect = offlinePerformanceData.frames.firstWhere(
      (frame) => frame.id == offlinePerformanceData.selectedFrameId,
      orElse: () => null,
    );
    if (frameToSelect != null) {
      data.selectedFrame = frameToSelect;
      _selectedFrameNotifier.value = frameToSelect;
    }
    if (offlinePerformanceData.selectedEvent != null) {
      for (var timelineEvent in data.timelineEvents) {
        final eventToSelect = timelineEvent.firstChildWithCondition((event) {
          return event.name == offlinePerformanceData.selectedEvent.name &&
              event.time == offlinePerformanceData.selectedEvent.time;
        });
        if (eventToSelect != null) {
          data
            ..selectedEvent = eventToSelect
            ..cpuProfileData = offlinePerformanceData.cpuProfileData;
          _selectedTimelineEventNotifier.value = eventToSelect;
          break;
        }
      }
    }

    if (offlinePerformanceData.cpuProfileData != null) {
      cpuProfilerController.loadProcessedData(
        offlinePerformanceData.cpuProfileData,
      );
    }
  }

  /// Exports the current timeline data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData =
        _exportController.encode(PerformanceScreen.id, data.json);
    return _exportController.downloadFile(encodedData);
  }

  @override
  List<TimelineEvent> matchesForSearch(String search) {
    if (search?.isEmpty ?? true) return [];
    final matches = <TimelineEvent>[];
    final events = List<TimelineEvent>.from(data.timelineEvents);
    for (final event in events) {
      breadthFirstTraversal<TimelineEvent>(event, action: (TimelineEvent e) {
        if (e.name.caseInsensitiveContains(search)) {
          matches.add(e);
          e.isSearchMatch = true;
        } else {
          e.isSearchMatch = false;
        }
      });
    }
    return matches;
  }

  Future<void> toggleHttpRequestLogging(bool state) async {
    await HttpService.toggleHttpRequestLogging(state);
    _httpTimelineLoggingEnabled.value = state;
  }

  Future<void> setTimelineStreams(List<RecordedTimelineStream> streams) async {
    for (final stream in streams) {
      assert(recordedStreams.contains(stream));
      stream.toggle(true);
    }
    await serviceManager.service
        .setVMTimelineFlags(streams.map((s) => s.name).toList());
  }

  // TODO(kenz): this is not as robust as we'd like. Revisit once
  // https://github.com/dart-lang/sdk/issues/41822 is addressed.
  Future<void> toggleTimelineStream(RecordedTimelineStream stream) async {
    final newValue = !stream.enabled.value;
    final timelineFlags =
        (await serviceManager.service.getVMTimelineFlags()).recordedStreams;
    if (timelineFlags.contains(stream.name) && !newValue) {
      timelineFlags.remove(stream.name);
    } else if (!timelineFlags.contains(stream.name) && newValue) {
      timelineFlags.add(stream.name);
    }
    await serviceManager.service.setVMTimelineFlags(timelineFlags);
    stream.toggle(newValue);
  }

  /// Clears the timeline data currently stored by the controller as well the
  /// VM timeline if a connected app is present.
  Future<void> clearData() async {
    if (serviceManager.connectedAppInitialized) {
      await serviceManager.service.clearVMTimeline();
    }
    allTraceEvents.clear();
    offlinePerformanceData = null;
    cpuProfilerController.reset();
    data?.clear();
    processor?.reset();
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
  }

  void recordTrace(Map<String, dynamic> trace) {
    data?.traceEvents?.add(trace);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timelinePollingRateLimiter?.dispose();
    cpuProfilerController.dispose();
    super.dispose();
  }
}
