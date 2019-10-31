// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:math' as math;

import '../config_specific/logger.dart';
import '../globals.dart';
import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../service_manager.dart';
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
  final _loadOfflineDataController = StreamController<TimelineData>.broadcast();

  /// Stream controller that notifies the timeline screen when a non-fatal error
  /// should be logged for the timeline.
  final _nonFatalErrorController = StreamController<String>.broadcast();

  Stream<TimelineEvent> get onSelectedTimelineEvent =>
      _selectedTimelineEventController.stream;

  Stream<TimelineData> get onLoadOfflineData =>
      _loadOfflineDataController.stream;

  Stream<String> get onNonFatalError => _nonFatalErrorController.stream;

  final frameBasedTimeline = FrameBasedTimeline();

  FullTimeline fullTimeline;

  TimelineData offlineTimelineData;

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
  set timelineData(TimelineData data) {
    if (timelineMode == TimelineMode.frameBased) {
      frameBasedTimeline.data = data;
    } else {
      fullTimeline.data = data;
    }
  }

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

  void loadOfflineData(TimelineData offlineData) {
    final traceEvents = [
      for (var trace in offlineData.traceEvents)
        TraceEventWrapper(
          TraceEvent(trace),
          DateTime.now().microsecondsSinceEpoch,
        )
    ];

    // TODO(kenz): once each trace event has a ui/gpu distinction bit added to
    // the trace, we will not need to infer thread ids. This is not robust.
    final uiThreadId = _threadIdForEvent(uiEventName, traceEvents);
    final gpuThreadId = _threadIdForEvent(gpuEventName, traceEvents);

    timelineMode = offlineData.timelineMode;

    // Load the snapshot in the mode it was exported from.
    if (offlineData is OfflineFrameBasedTimelineData) {
      offlineTimelineData = offlineData.shallowClone();
      frameBasedTimeline.data = offlineData.shallowClone();
      frameBasedTimeline.processor = FrameBasedTimelineProcessor(
        uiThreadId: uiThreadId,
        gpuThreadId: gpuThreadId,
        timelineController: this,
      );

      for (var event in traceEvents) {
        frameBasedTimeline.processor.processTraceEvent(event, immediate: true);
      }
      // Make a final call to [maybeAddPendingEvents] so that we complete the
      // processing for every frame in the snapshot.
      frameBasedTimeline.processor.maybeAddPendingEvents();
    } else if (offlineData is OfflineFullTimelineData) {
      offlineTimelineData = offlineData.shallowClone();
      fullTimeline.data = offlineData.shallowClone();
      fullTimeline.processor = FullTimelineProcessor(
        uiThreadId: uiThreadId,
        gpuThreadId: gpuThreadId,
        timelineController: this,
      )..processTimeline(traceEvents);
    }

    if (cpuProfileData != null) {
      _cpuProfileTransformer.processData(offlineData.cpuProfileData);
    }

    setOfflineData();
    _loadOfflineDataController.add(offlineData);

    if (offlineTimelineData.selectedEvent != null) {
      // TODO(kenz): the flame chart should listen to this stream and
      // programmatically select the flame chart node that corresponds to
      // the selected event.
      _selectedTimelineEventController.add(offlineTimelineData.selectedEvent);
    }

    if (offlineTimelineData is OfflineFullTimelineData) {
      fullTimeline._timelineProcessedController.add(true);
    }
  }

  int _threadIdForEvent(
    String targetEventName,
    List<TraceEventWrapper> traceEvents,
  ) {
    const invalidThreadId = -1;
    return traceEvents
            .firstWhere((trace) => trace.event.name == targetEventName,
                orElse: () => null)
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
        frameBasedTimeline._selectedFrameController.add(frameToSelect);

        if (offlineTimelineData.selectedEvent != null) {
          eventToSelect = frameToSelect
              .findTimelineEvent(offlineTimelineData.selectedEvent);
        }
      }
    } else if (offlineTimelineData is OfflineFullTimelineData) {
      final offlineData = offlineTimelineData as OfflineFullTimelineData;
      if (offlineData.selectedEvent != null) {
        eventToSelect = fullTimeline.data.timelineEvents.firstWhere(
          (event) =>
              event.name == offlineData.selectedEvent.name &&
              event.time.start.inMicroseconds ==
                  offlineData.selectedEvent.time.start.inMicroseconds &&
              event.time.end.inMicroseconds ==
                  offlineData.selectedEvent.time.end.inMicroseconds,
          orElse: () => null,
        );
      }
    }

    if (eventToSelect != null) {
      timelineData
        ..selectedEvent = eventToSelect
        ..cpuProfileData = offlineTimelineData.cpuProfileData;
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
    timelineData?.traceEvents?.add(trace);
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

  Future<double> get displayRefreshRate async {
    final refreshRate =
        await serviceManager.getDisplayRefreshRate() ?? defaultRefreshRate;
    data?.displayRefreshRate = refreshRate;
    return refreshRate;
  }

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
    data?.clear();
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

  /// The end timestamp for the data in this timeline.
  ///
  /// Track it here so that we can cache the value as we add timeline events.
  int get endTimestampMicros => _endTimestampMicros;
  int _endTimestampMicros = -1;

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
    _endTimestampMicros =
        math.max(_endTimestampMicros, event.time.end.inMicroseconds);
  }

  void clear() {
    data?.clear();
    processor?.reset();
  }
}

enum TimelineMode {
  frameBased,
  full,
}
