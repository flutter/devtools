// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import '../auto_dispose.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../service_manager.dart';
import '../trace_event.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import 'html_timeline_model.dart';
import 'html_timeline_processor.dart';
import 'html_timeline_service.dart';

const String timelineScreenId = 'timeline';

/// This class contains the business logic for [timeline_screen.dart].
///
/// The controller manages the timeline data model and communicates with the
/// view to give and receive data updates. It also manages data processing via
/// [TimelineProcessor] and [CpuProfileTransformer], and it communicates with
/// [TimelineService].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class TimelineController implements DisposableController {
  TimelineController() {
    timelineService = TimelineService(this);
    fullTimeline = FullTimeline(this);
    frameBasedTimeline = FrameBasedTimeline(this);
    timelines = [frameBasedTimeline, fullTimeline];
  }

  final cpuProfilerController = CpuProfilerController();

  /// Notifies that a timeline event was selected.
  ValueListenable get selectedTimelineEventNotifier =>
      _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent>(null);

  /// Stream controller that notifies that offline data was loaded into the
  /// timeline.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [timelineData].
  final _loadOfflineDataController = StreamController<OfflineData>.broadcast();

  /// Stream controller that notifies the timeline screen when a non-fatal error
  /// should be logged for the timeline.
  final _nonFatalErrorController = StreamController<String>.broadcast();

  Stream<OfflineData> get onLoadOfflineData =>
      _loadOfflineDataController.stream;

  Stream<String> get onNonFatalError => _nonFatalErrorController.stream;

  /// Stream controller that notifies the timeline has been cleared.
  final _clearController = StreamController<bool>.broadcast();

  Stream<bool> get onTimelineCleared => _clearController.stream;

  TimelineBase get timeline =>
      timelineModeNotifier.value == TimelineMode.frameBased
          ? frameBasedTimeline
          : fullTimeline;

  FrameBasedTimeline frameBasedTimeline;

  FullTimeline fullTimeline;

  List<TimelineBase> timelines;

  TimelineData offlineTimelineData;

  TimelineService timelineService;

  ValueListenable get timelineModeNotifier => _timelineModeNotifier;
  final _timelineModeNotifier =
      ValueNotifier<TimelineMode>(TimelineMode.frameBased);

  /// Trace events we received while listening to the Timeline event stream.
  ///
  /// This does not include events that we receive while paused (if
  /// [timelineModeNotifier] == [TimelineMode.frameBased]) or stopped (if
  /// [timelineModeNotifier] == [TimelineMode.full]).
  ///
  /// These events will be used to switch timeline modes (frameBased vs full).
  /// The selected mode will process these events using the respective processor
  /// ([frameBasedTimeline.processor] or
  /// [fullTimeline.processor]).
  List<TraceEventWrapper> allTraceEvents = [];

  bool get hasStarted =>
      frameBasedTimeline.hasStarted && fullTimeline.hasStarted;

  void selectTimelineMode(TimelineMode mode) {
    _timelineModeNotifier.value = mode;
  }

  Future<void> selectTimelineEvent(TimelineEvent event) async {
    if (event == null || timeline.data.selectedEvent == event) return;

    timeline.data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;

    cpuProfilerController.reset();

    // Fetch a profile if we are not in offline mode and if the profiler is
    // enabled.
    if ((!offlineMode || offlineTimelineData == null) &&
        cpuProfilerController.profilerEnabled) {
      await getCpuProfileForSelectedEvent();
    }
  }

  // TODO(kenz): remove this method once html app is deleted. This is a
  // workaround to avoid fixing bugs in the DevTools html app. Modifying
  // [selectTimelineEvent] to work for Flutter DevTools broke the html app, so
  // this method fixes the regression without wasting resources to make the html
  // and flutter code 100% compatible.
  void htmlSelectTimelineEvent(TimelineEvent event) {
    if (event == null || timeline.data.selectedEvent == event) return;
    timeline.data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;
  }

  Future<void> getCpuProfileForSelectedEvent() async {
    final selectedEvent = timeline.data.selectedEvent;
    if (!selectedEvent.isUiEvent) return;

    await cpuProfilerController.pullAndProcessProfile(
      startMicros: selectedEvent.time.start.inMicroseconds,
      extentMicros: selectedEvent.time.duration.inMicroseconds,
    );
    timeline.data.cpuProfileData = cpuProfilerController.dataNotifier.value;
  }

  Future<void> loadOfflineData(OfflineData offlineData) async {
    await _offlineModeChanged();
    final traceEvents = [
      for (var trace in offlineData.traceEvents)
        TraceEventWrapper(
          TraceEvent(trace),
          DateTime.now().microsecondsSinceEpoch,
        )
    ];

    // TODO(kenz): once each trace event has a ui/gpu distinction bit added to
    // the trace, we will not need to infer thread ids. This is not robust.
    final uiThreadId =
        _threadIdForEvents({uiEventName, uiEventNameOld}, traceEvents);
    final gpuThreadId = _threadIdForEvents({gpuEventName}, traceEvents);

    _timelineModeNotifier.value = offlineData.timelineMode;
    offlineTimelineData = offlineData.shallowClone();
    timeline
      ..data = offlineData.shallowClone()
      ..processor.primeThreadIds(
        uiThreadId: uiThreadId,
        gpuThreadId: gpuThreadId,
      );
    await timeline.processTraceEvents(traceEvents);

    if (timeline.data.cpuProfileData != null) {
      await cpuProfilerController.transformer
          .processData(offlineTimelineData.cpuProfileData);
    }

    setOfflineData();
    _loadOfflineDataController.add(offlineTimelineData);

    if (offlineTimelineData.selectedEvent != null) {
      // TODO(kenz): the flame chart should listen to this stream and
      // programmatically select the flame chart node that corresponds to
      // the selected event.
      _selectedTimelineEventNotifier.value = offlineTimelineData.selectedEvent;
    }

    if (offlineTimelineData is OfflineFullTimelineData) {
      fullTimeline._timelineProcessedController.add(true);
    }
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
    TimelineEvent eventToSelect;
    if (offlineTimelineData is OfflineFrameBasedTimelineData) {
      final offlineData = offlineTimelineData as OfflineFrameBasedTimelineData;
      final frameToSelect = offlineData.frames.firstWhere(
        (frame) => frame.id == offlineData.selectedFrameId,
        orElse: () => null,
      );
      if (frameToSelect != null) {
        frameBasedTimeline.data.selectedFrame = frameToSelect;
        // TODO(kenz): frames bar chart should listen to this stream and
        // programmatially select the frame from the offline snapshot.
        frameBasedTimeline._selectedFrameNotifier.value = frameToSelect;

        if (offlineTimelineData.selectedEvent != null) {
          eventToSelect = frameToSelect
              .findTimelineEvent(offlineTimelineData.selectedEvent);
        }
      }
    } else if (offlineTimelineData is OfflineFullTimelineData) {
      final offlineData = offlineTimelineData as OfflineFullTimelineData;
      if (offlineData.selectedEvent != null) {
        for (var timelineEvent in fullTimeline.data.timelineEvents) {
          final e = timelineEvent.firstChildWithCondition((event) {
            return event.name == offlineData.selectedEvent.name &&
                event.time == offlineData.selectedEvent.time;
          });
          if (e != null) {
            eventToSelect = e;
            break;
          }
        }
      }
    }

    if (eventToSelect != null) {
      timeline.data
        ..selectedEvent = eventToSelect
        ..cpuProfileData = offlineTimelineData.cpuProfileData;
      _selectedTimelineEventNotifier.value = eventToSelect;
    }

    if (offlineTimelineData.cpuProfileData != null) {
      cpuProfilerController.loadOfflineData(offlineTimelineData.cpuProfileData);
    }
  }

  Future<void> _offlineModeChanged() async {
    await clearData();
    if (serviceManager.connectedApp != null) {
      await timelineService.updateListeningState(true);
    }
  }

  Future<void> exitOfflineMode() async {
    offlineMode = false;
    await _offlineModeChanged();
  }

  Future<void> clearData() async {
    if (serviceManager.hasConnection) {
      await serviceManager.service.clearVMTimeline();
    }
    for (var timeline in timelines) timeline.clear();
    allTraceEvents.clear();
    offlineTimelineData = null;
    _selectedTimelineEventNotifier.value = null;
    cpuProfilerController.reset();
    _clearController.add(true);
  }

  void recordTrace(Map<String, dynamic> trace) {
    timeline.data?.traceEvents?.add(trace);
  }

  void recordTraceForTimelineEvent(TimelineEvent event) {
    recordTrace(event.beginTraceEventJson);
    event.children.forEach(recordTraceForTimelineEvent);
    if (event.endTraceEventJson != null) {
      recordTrace(event.endTraceEventJson);
    }
  }

  void logNonFatalError(String message) {
    _nonFatalErrorController.add(message);
  }

  @override
  void dispose() {
    cpuProfilerController.dispose();
    _selectedTimelineEventNotifier.dispose();
    _timelineModeNotifier.dispose();
    _clearController.close();
    _loadOfflineDataController.close();
    _nonFatalErrorController.close();
  }
}

class FrameBasedTimeline
    extends TimelineBase<FrameBasedTimelineData, FrameBasedTimelineProcessor> {
  FrameBasedTimeline(this._timelineController) {
    processor = FrameBasedTimelineProcessor(_timelineController);
  }

  final TimelineController _timelineController;

  /// Notifies that a frame has been added to the timeline.
  ValueListenable get frameAddedNotifier => _frameAddedNotifier;
  final _frameAddedNotifier = ValueNotifier<TimelineFrame>(null);

  /// Notifies that a timeline frame has been selected.
  ValueListenable get selectedFrameNotifier => _selectedFrameNotifier;
  final _selectedFrameNotifier = ValueNotifier<TimelineFrame>(null);

  Future<double> get displayRefreshRate async {
    final refreshRate =
        await serviceManager.getDisplayRefreshRate() ?? defaultRefreshRate;
    data?.displayRefreshRate = refreshRate;
    return refreshRate;
  }

  /// Whether the timeline has been manually paused via the Pause button.
  bool manuallyPaused = false;

  /// Notifies that the timeline has been paused.
  ValueListenable get pausedNotifier => _pausedNotifier;
  final _pausedNotifier = ValueNotifier<bool>(false);

  void pause({bool manual = false}) {
    manuallyPaused = manual;
    _pausedNotifier.value = true;
  }

  void resume() {
    manuallyPaused = false;
    _pausedNotifier.value = false;
  }

  void selectFrame(TimelineFrame frame) {
    if (frame == null || data.selectedFrame == frame || !hasStarted) {
      return;
    }
    data.selectedFrame = frame;
    _selectedFrameNotifier.value = frame;

    data.selectedEvent = null;
    _timelineController._selectedTimelineEventNotifier.value = null;
    data.cpuProfileData = null;
    _timelineController.cpuProfilerController.reset();

    if (debugTimeline && frame != null) {
      final buf = StringBuffer();
      buf.writeln('UI timeline event for frame ${frame.id}:');
      frame.uiEventFlow.format(buf, '  ');
      buf.writeln('\nUI trace for frame ${frame.id}');
      frame.uiEventFlow.writeTraceToBuffer(buf);
      buf.writeln('\nGPU timeline event frame ${frame.id}:');
      frame.gpuEventFlow.format(buf, '  ');
      buf.writeln('\nGPU trace for frame ${frame.id}');
      frame.gpuEventFlow.writeTraceToBuffer(buf);
      log(buf.toString());
    }
  }

  void addFrame(TimelineFrame frame) {
    data.frames.add(frame);
    _frameAddedNotifier.value = frame;
  }

  @override
  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents) {
    for (var event in traceEvents) {
      processor.processTraceEvent(event, immediate: true);
    }
    // Make a final call to [maybeAddPendingEvents] so that we complete the
    // processing for every frame in the snapshot.
    processor.maybeAddPendingEvents();
  }

  @override
  void clear() {
    super.clear();
    _frameAddedNotifier.value = null;
    _selectedFrameNotifier.value = null;
    _pausedNotifier.value = false;
  }
}

class FullTimeline
    extends TimelineBase<FullTimelineData, FullTimelineProcessor> {
  FullTimeline(this._timelineController) {
    processor = FullTimelineProcessor(_timelineController);
  }

  final TimelineController _timelineController;

  final _timelineProcessedController = StreamController<bool>.broadcast();

  /// Notifies when an empty timeline recording finishes
  ValueListenable get emptyRecordingNotifier => _emptyRecordingNotifier;
  final _emptyRecordingNotifier = ValueNotifier<bool>(false);

  Stream<bool> get onTimelineProcessed => _timelineProcessedController.stream;

  /// Notifies that the timeline is currently being recorded.
  ValueListenable get recordingNotifier => _recordingNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);

  /// Notifies that the recorded timeline data is currently being processed.
  ValueListenable get processingNotifier => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  void startRecording() async {
    _recordingNotifier.value = true;
  }

  Future<void> stopRecording() async {
    _recordingNotifier.value = false;

    if (_timelineController.allTraceEvents.isEmpty) {
      _emptyRecordingNotifier.value = true;
      return;
    }

    _processingNotifier.value = true;
    await processTraceEvents(_timelineController.allTraceEvents);
    _processingNotifier.value = false;
    _timelineProcessedController.add(true);
  }

  void addTimelineEvent(TimelineEvent event) {
    data.addTimelineEvent(event);
  }

  @override
  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents) async {
    await processor.processTimeline(traceEvents);
    _timelineController.fullTimeline.data.initializeEventGroups();
    if (_timelineController.fullTimeline.data.eventGroups.isEmpty) {
      _emptyRecordingNotifier.value = true;
    }
  }

  @override
  void clear() {
    super.clear();
    _recordingNotifier.value = false;
    _processingNotifier.value = false;
    _emptyRecordingNotifier.value = false;
  }
}

abstract class TimelineBase<T extends TimelineData,
    V extends TimelineProcessor> {
  T data;

  V processor;

  bool get hasStarted => data != null;

  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents);

  void clear() {
    data?.clear();
    processor?.reset();
  }
}

enum TimelineMode {
  frameBased,
  full,
}
