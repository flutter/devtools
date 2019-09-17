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
/// protocols [TimelineProtocol] and [CpuProfileTransformer], and it communicates
/// with [TimelineService].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class TimelineController {
  TimelineController() {
    timelineService = TimelineService(this);
  }

  /// Stream controller that notifies a frame was added to the timeline.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [timelineData.frames].
  final frameAddedController = StreamController<TimelineFrame>.broadcast();

  /// Stream controller that notifies a frame was selected.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [timelineData.selectedFrame].
  final _selectedFrameController = StreamController<TimelineFrame>.broadcast();

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

  Stream<TimelineFrame> get onFrameAdded => frameAddedController.stream;

  Stream<TimelineFrame> get onSelectedFrame => _selectedFrameController.stream;

  Stream<TimelineEvent> get onSelectedTimelineEvent =>
      _selectedTimelineEventController.stream;

  Stream<OfflineTimelineData> get onLoadOfflineData =>
      _loadOfflineDataController.stream;

  Stream<String> get onNonFatalError => _nonFatalErrorController.stream;

  TimelineData timelineData;

  OfflineTimelineData offlineTimelineData;

  TimelineService timelineService;

  TimelineProtocol timelineProtocol;

  final _cpuProfileTransformer = CpuProfileTransformer();

  final _cpuProfilerService = CpuProfilerService();

  TimelineMode timelineMode = TimelineMode.frameBased;

  /// Whether the timeline has been manually paused via the Pause button.
  bool manuallyPaused = false;

  /// Whether the timeline is being recorded, which will only occur when the
  /// timeline is not in display-by-frame mode.
  bool recording = false;

  bool get hasStarted => timelineData != null;

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

  void startRecording() {
    // TODO(kenz): kick off timeline recording here.
    recording = true;
  }

  void stopRecording() {
    // TODO(kenz): kick off trace event processing here.
    recording = false;
  }

  void selectFrame(TimelineFrame frame) {
    if (frame == null || timelineData.selectedFrame == frame || !hasStarted) {
      return;
    }
    timelineData.selectedFrame = frame;
    timelineData.selectedEvent = null;
    timelineData.cpuProfileData = null;
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

  void selectTimelineEvent(TimelineEvent event) {
    if (event == null || timelineData.selectedEvent == event) {
      return;
    }
    timelineData.selectedEvent = event;
    _selectedTimelineEventController.add(event);
  }

  void addFrame(TimelineFrame frame) {
    timelineData.frames.add(frame);
    frameAddedController.add(frame);
  }

  Future<void> getCpuProfileForSelectedEvent() async {
    if (!timelineData.selectedEvent.isUiEvent) return;

    assert(timelineData.selectedEvent.frameId == timelineData.selectedFrame.id);

    timelineData.selectedFrame.cpuProfileData ??=
        await _cpuProfilerService.getCpuProfile(
      startMicros:
          timelineData.selectedFrame.uiEventFlow.time.start.inMicroseconds,
      extentMicros:
          timelineData.selectedFrame.uiEventFlow.time.duration.inMicroseconds,
    );

    timelineData.cpuProfileData = CpuProfileData.subProfile(
      timelineData.selectedFrame.cpuProfileData,
      timelineData.selectedEvent.time,
    );
    _cpuProfileTransformer.processData(timelineData.cpuProfileData);
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

  void loadOfflineData(OfflineTimelineData offlineData) {
    timelineData = offlineData.copy();
    offlineTimelineData = offlineData.copy();

    final traceEvents =
        offlineData.traceEvents.map((trace) => TraceEvent(trace)).toList();

    // TODO(kenz): once each trace event has a ui/gpu distinction bit added to
    // the trace, we will not need to infer thread ids. Since we control the
    // format of the input, this is okay for now.
    final uiThreadId = traceEvents.first.threadId;
    final gpuThreadId = traceEvents.last.threadId;

    timelineProtocol = TimelineProtocol(
      timelineController: this,
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
    );

    for (TraceEvent event in traceEvents) {
      timelineProtocol.processTraceEvent(event, immediate: true);
    }
    // Make a final call to [maybeAddPendingEvents] so that we complete the
    // processing for every frame in the snapshot.
    timelineProtocol.maybeAddPendingEvents();

    if (timelineData.cpuProfileData != null) {
      _cpuProfileTransformer.processData(timelineData.cpuProfileData);
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
      timelineData.selectedFrame = frameToSelect;
      // TODO(kenz): frames bar chart should listen to this stream and
      // programmatially select the frame from the offline snapshot.
      _selectedFrameController.add(frameToSelect);

      if (offlineTimelineData.selectedEvent != null) {
        final eventToSelect =
            frameToSelect.findTimelineEvent(offlineTimelineData.selectedEvent);
        if (eventToSelect != null) {
          timelineData.selectedEvent = eventToSelect;
          timelineData.cpuProfileData = offlineTimelineData.cpuProfileData;
          // TODO(kenz): frame flame chart should listen to this stream and
          // programmatically select the flame chart item that corresponds to
          // the selected event from the offline snapshot.
          _selectedTimelineEventController.add(eventToSelect);
        }
      }
    }
  }

  Future<void> exitOfflineMode({bool clearTimeline = true}) async {
    if (clearTimeline) {
      await timelineData.clear();
    }
    offlineTimelineData = null;
  }

  Future<double> get displayRefreshRate async =>
      timelineData?.displayRefreshRate ??
      await serviceManager.getDisplayRefreshRate();

  void logNonFatalError(String message) {
    _nonFatalErrorController.add(message);
  }
}

enum TimelineMode {
  frameBased,
  full,
}
