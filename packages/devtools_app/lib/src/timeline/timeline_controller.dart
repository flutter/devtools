// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import '../config_specific/logger.dart';
import '../globals.dart';
import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import 'timeline_model.dart';
import 'timeline_protocol.dart';
import 'timeline_service.dart';

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
class TimelineController {
  TimelineController() {
    timelineService = TimelineService(this);
    fullTimeline = FullTimeline(this);
  }

  /// Stream controller that notifies a timeline event was selected.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [timelineData.selectedEvent]. We send the
  /// [FrameFlameChartItem] so that we can persist the colors through to the
  /// event details view.
  final _selectedTimelineEventController =
      StreamController<TimelineEvent>.broadcast();

  /// Stream controller that notifies that offline data was loaded into the
  /// timeline.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [timelineData].
  final _loadOfflineDataController =
      StreamController<OfflineTimelineData>.broadcast();

  /// Stream controller that notifies the timeline screen when a non-fatal error
  /// should be logged for the timeline.
  final _nonFatalErrorController = StreamController<String>.broadcast();

  Stream<TimelineEvent> get onSelectedTimelineEvent =>
      _selectedTimelineEventController.stream;

  Stream<OfflineTimelineData> get onLoadOfflineData =>
      _loadOfflineDataController.stream;

  Stream<String> get onNonFatalError => _nonFatalErrorController.stream;

  final frameBasedTimeline = FrameBasedTimeline();

  FullTimeline fullTimeline;

  OfflineTimelineData offlineTimelineData;

  TimelineService timelineService;

  final _cpuProfileTransformer = CpuProfileTransformer();

  final _cpuProfilerService = CpuProfilerService();

  TimelineMode timelineMode = TimelineMode.frameBased;

  /// Trace events we received while listening to the Timeline event stream.
  ///
  /// This does not include events that we receive while paused (if
  /// [timelineMode] == [TimelineMode.frameBased]) or stopped (if
  /// [timelineMode] == [TimelineMode.full]).
  ///
  /// These events will be used to switch timeline modes (frameBased vs full).
  /// The selected mode will process these events using the respective processor
  /// ([frameBasedTimeline.processor] or
  /// [fullTimeline.processor]).
  List<TraceEventWrapper> allTraceEvents = [];

  bool get hasStarted =>
      frameBasedTimeline.hasStarted && fullTimeline.hasStarted;

  TimelineData get timelineData => timelineMode == TimelineMode.frameBased
      ? frameBasedTimeline.data
      : fullTimeline.data;

  CpuProfileData get cpuProfileData =>
      timelineMode == TimelineMode.frameBased || offlineMode
          ? frameBasedTimeline.data?.cpuProfileData
          : fullTimeline.data?.cpuProfileData;

  void selectTimelineEvent(TimelineEvent event) {
    if (event == null || timelineData.selectedEvent == event) return;
    timelineData.selectedEvent = event;
    _selectedTimelineEventController.add(event);
  }

  Future<void> getCpuProfileForSelectedEvent() async {
    final selectedEvent = timelineData.selectedEvent;
    if (!selectedEvent.isUiEvent) return;

    final cpuProfileData = await _cpuProfilerService.getCpuProfile(
      startMicros: selectedEvent.time.start.inMicroseconds,
      extentMicros: selectedEvent.time.duration.inMicroseconds,
    );

    timelineData.cpuProfileData = cpuProfileData;
    _cpuProfileTransformer.processData(cpuProfileData);
  }

  void loadOfflineData(OfflineTimelineData offlineData) {
    // TODO(kenz): loading offline data should respect user's current timeline
    // mode (frameBased vs full). It should also support toggling modes.
    frameBasedTimeline.data = offlineData.copy();
    offlineTimelineData = offlineData.copy();

    final traceEvents =
        offlineData.traceEvents.map((trace) => TraceEvent(trace)).toList();

    // TODO(kenz): once each trace event has a ui/gpu distinction bit added to
    // the trace, we will not need to infer thread ids. Since we control the
    // format of the input, this is okay for now.
    final uiThreadId = traceEvents.first.threadId;
    final gpuThreadId = traceEvents.last.threadId;

    frameBasedTimeline.processor = FrameBasedTimelineProcessor(
      timelineController: this,
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
    );

    for (TraceEvent event in traceEvents) {
      frameBasedTimeline.processor.processTraceEvent(
        TraceEventWrapper(event, DateTime.now().millisecondsSinceEpoch),
        immediate: true,
      );
    }
    // Make a final call to [maybeAddPendingEvents] so that we complete the
    // processing for every frame in the snapshot.
    frameBasedTimeline.processor.maybeAddPendingEvents();

    if (frameBasedTimeline.data.cpuProfileData != null) {
      _cpuProfileTransformer
          .processData(frameBasedTimeline.data.cpuProfileData);
    }

    setOfflineData();
    _loadOfflineDataController.add(offlineData);
  }

  void setOfflineData() {
    final frameToSelect = offlineTimelineData.frames.firstWhere(
      (frame) => frame.id == offlineTimelineData.selectedFrameId,
      orElse: () => null,
    );
    if (frameToSelect != null) {
      frameBasedTimeline.data.selectedFrame = frameToSelect;
      // TODO(kenz): frames bar chart should listen to this stream and
      // programmatially select the frame from the offline snapshot.
      frameBasedTimeline._selectedFrameController.add(frameToSelect);

      if (offlineTimelineData.selectedEvent != null) {
        final eventToSelect =
            frameToSelect.findTimelineEvent(offlineTimelineData.selectedEvent);
        if (eventToSelect != null) {
          frameBasedTimeline.data.selectedEvent = eventToSelect;
          frameBasedTimeline.data.cpuProfileData =
              offlineTimelineData.cpuProfileData;
          // TODO(kenz): frame flame chart should listen to this stream and
          // programmatically select the flame chart item that corresponds to
          // the selected event from the offline snapshot.
          _selectedTimelineEventController.add(eventToSelect);
        }
      }
    }
  }

  void exitOfflineMode({bool clearTimeline = true}) {
    clearData();
    offlineTimelineData = null;
  }

  Future<void> clearData() async {
    if (serviceManager.hasConnection) {
      await serviceManager.service.clearVMTimeline();
    }
    frameBasedTimeline.clear();
    fullTimeline.clear();
    allTraceEvents.clear();
  }

  void recordTrace(Map<String, dynamic> trace) {
    timelineData.traceEvents.add(trace);
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
}

class FrameBasedTimeline {
  /// Stream controller that notifies a frame was added to the timeline.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [frameBasedTimelineData.frames].
  final _frameAddedController = StreamController<TimelineFrame>.broadcast();

  /// Stream controller that notifies a frame was selected.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [frameBasedTimelineData.selectedFrame].
  final _selectedFrameController = StreamController<TimelineFrame>.broadcast();

  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;

  Stream<TimelineFrame> get onSelectedFrame => _selectedFrameController.stream;

  Future<double> get displayRefreshRate async =>
      data?.displayRefreshRate ?? await serviceManager.getDisplayRefreshRate();

  FrameBasedTimelineData data;

  FrameBasedTimelineProcessor processor;

  bool get hasStarted => data != null;

  /// Whether the timeline has been manually paused via the Pause button.
  bool manuallyPaused = false;

  bool get paused => _paused;

  bool _paused = false;

  void pause({bool manual = false}) {
    manuallyPaused = manual;
    _paused = true;
  }

  void resume() {
    manuallyPaused = false;
    _paused = false;
  }

  void selectFrame(TimelineFrame frame) {
    if (frame == null || data.selectedFrame == frame || !hasStarted) {
      return;
    }
    data.selectedFrame = frame;
    data.selectedEvent = null;
    data.cpuProfileData = null;
    _selectedFrameController.add(frame);

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
    _frameAddedController.add(frame);
  }

  void clear() {
    data.clear();
  }
}

class FullTimeline {
  FullTimeline(this._timelineController);

  final TimelineController _timelineController;

  final _timelineProcessedController = StreamController<bool>.broadcast();

  final _noEventsRecordedController = StreamController<bool>.broadcast();

  Stream<bool> get onTimelineProcessed => _timelineProcessedController.stream;

  Stream<bool> get onNoEventsRecorded => _noEventsRecordedController.stream;

  FullTimelineData data;

  FullTimelineProcessor processor;

  bool get hasStarted => data != null;

  /// Whether the timeline is being recorded.
  bool recording = false;

  void startRecording() async {
    recording = true;
  }

  void stopRecording() {
    recording = false;

    if (_timelineController.allTraceEvents.isEmpty) {
      _noEventsRecordedController.add(true);
      return;
    }

    processor.processTimeline(_timelineController.allTraceEvents);
    _timelineController.fullTimeline.data.initializeEventBuckets();
    _timelineProcessedController.add(true);
  }

  void addTimelineEvent(TimelineEvent event) {
    data.timelineEvents.add(event);
  }

  void clear() {
    data.clear();
    processor.reset();
  }
}

enum TimelineMode {
  frameBased,
  full,
}
