// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:meta/meta.dart';

import '../config_specific/logger.dart';
import '../globals.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../service_manager.dart';
import 'timeline_model.dart';
import 'timeline_processor.dart';
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
    timelines = [frameBasedTimeline, fullTimeline];
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
  final _loadOfflineDataController = StreamController<OfflineData>.broadcast();

  /// Stream controller that notifies the timeline screen when a non-fatal error
  /// should be logged for the timeline.
  final _nonFatalErrorController = StreamController<String>.broadcast();

  Stream<TimelineEvent> get onSelectedTimelineEvent =>
      _selectedTimelineEventController.stream;

  Stream<OfflineData> get onLoadOfflineData =>
      _loadOfflineDataController.stream;

  Stream<String> get onNonFatalError => _nonFatalErrorController.stream;

  TimelineBase get timeline => timelineMode == TimelineMode.frameBased
      ? frameBasedTimeline
      : fullTimeline;

  final frameBasedTimeline = FrameBasedTimeline();

  FullTimeline fullTimeline;

  List<TimelineBase> timelines;

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

  void selectTimelineEvent(TimelineEvent event) {
    if (event == null || timeline.data.selectedEvent == event) return;
    timeline.data.selectedEvent = event;
    _selectedTimelineEventController.add(event);
  }

  Future<void> getCpuProfileForSelectedEvent() async {
    final selectedEvent = timeline.data.selectedEvent;
    if (!selectedEvent.isUiEvent) return;

    final cpuProfileData = await _cpuProfilerService.getCpuProfile(
      startMicros: selectedEvent.time.start.inMicroseconds,
      extentMicros: selectedEvent.time.duration.inMicroseconds,
    );

    timeline.data.cpuProfileData = cpuProfileData;
    _cpuProfileTransformer.processData(cpuProfileData);
  }

  void loadOfflineData(OfflineData offlineData) {
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
    offlineTimelineData = offlineData.shallowClone();
    timeline
      ..data = offlineData.shallowClone()
      ..initProcessor(
        uiThreadId: uiThreadId,
        gpuThreadId: gpuThreadId,
        timelineController: this,
      )
      ..processTraceEvents(traceEvents);

    if (timeline.data.cpuProfileData != null) {
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
      _selectedTimelineEventController.add(eventToSelect);
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
}

class FrameBasedTimeline
    extends TimelineBase<FrameBasedTimelineData, FrameBasedTimelineProcessor> {
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

  @override
  void initProcessor({
    @required int uiThreadId,
    @required int gpuThreadId,
    @required TimelineController timelineController,
  }) {
    processor = FrameBasedTimelineProcessor(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
      timelineController: timelineController,
    );
  }

  @override
  void processTraceEvents(List<TraceEventWrapper> traceEvents) {
    for (var event in traceEvents) {
      processor.processTraceEvent(event, immediate: true);
    }
    // Make a final call to [maybeAddPendingEvents] so that we complete the
    // processing for every frame in the snapshot.
    processor.maybeAddPendingEvents();
  }
}

class FullTimeline
    extends TimelineBase<FullTimelineData, FullTimelineProcessor> {
  FullTimeline(this._timelineController);

  final TimelineController _timelineController;

  final _timelineProcessedController = StreamController<bool>.broadcast();

  final _noEventsRecordedController = StreamController<bool>.broadcast();

  Stream<bool> get onTimelineProcessed => _timelineProcessedController.stream;

  Stream<bool> get onNoEventsRecorded => _noEventsRecordedController.stream;

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

    processTraceEvents(_timelineController.allTraceEvents);
    _timelineProcessedController.add(true);
  }

  void addTimelineEvent(TimelineEvent event) {
    data.addTimelineEvent(event);
  }

  @override
  void initProcessor({
    @required int uiThreadId,
    @required int gpuThreadId,
    @required TimelineController timelineController,
  }) {
    processor = FullTimelineProcessor(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
      timelineController: timelineController,
    );
  }

  @override
  void processTraceEvents(List<TraceEventWrapper> traceEvents) {
    processor.processTimeline(traceEvents);
    _timelineController.fullTimeline.data.initializeEventBuckets();
  }
}

abstract class TimelineBase<T extends TimelineData,
    V extends TimelineProcessor> {
  T data;

  V processor;

  bool get hasStarted => data != null;

  void initProcessor({
    @required int uiThreadId,
    @required int gpuThreadId,
    @required TimelineController timelineController,
  });

  void processTraceEvents(List<TraceEventWrapper> traceEvents);

  void clear() {
    data?.clear();
    processor?.reset();
  }
}

enum TimelineMode {
  frameBased,
  full,
}
