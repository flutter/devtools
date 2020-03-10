// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import '../../auto_dispose.dart';
import '../../config_specific/logger/logger.dart';
import '../../globals.dart';
import '../../profiler/cpu_profile_controller.dart';
import '../../profiler/cpu_profile_transformer.dart';
import '../../service_manager.dart';
import '../../ui/fake_flutter/fake_flutter.dart';
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
class TimelineController implements DisposableController {
  TimelineController() {
    timelineService = TimelineService(this);
    processor = TimelineProcessor(this);
  }

  final cpuProfilerController = CpuProfilerController();

  /// Notifies that a timeline event was selected.
  ValueListenable get selectedTimelineEvent => _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent>(null);

  /// Notifies that a timeline frame has been selected.
  ValueListenable get selectedFrame => _selectedFrameNotifier;
  final _selectedFrameNotifier = ValueNotifier<TimelineFrame>(null);

  /// Notifies when an empty timeline recording finishes
  ValueListenable get emptyRecording => _emptyRecordingNotifier;
  final _emptyRecordingNotifier = ValueNotifier<bool>(false);

  /// Notifies that the timeline is currently being recorded.
  ValueListenable get recording => _recordingNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);

  /// Notifies that the recorded timeline data is currently being processed.
  ValueListenable get processing => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  /// Stream controller that notifies the timeline has been processed.
  Stream<bool> get onTimelineProcessed => _timelineProcessedController.stream;
  final _timelineProcessedController = StreamController<bool>.broadcast();

  /// Stream controller that notifies that offline data was loaded into the
  /// timeline.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [timelineData].
  final _loadOfflineDataController =
      StreamController<OfflineTimelineData>.broadcast();

  Stream<OfflineTimelineData> get onLoadOfflineData =>
      _loadOfflineDataController.stream;

  /// Stream controller that notifies the timeline screen when a non-fatal error
  /// should be logged for the timeline.
  final _nonFatalErrorController = StreamController<String>.broadcast();

  Stream<String> get onNonFatalError => _nonFatalErrorController.stream;

  /// Stream controller that notifies the timeline has been cleared.
  final _clearController = StreamController<bool>.broadcast();

  Stream<bool> get onTimelineCleared => _clearController.stream;

  TimelineData data;

  TimelineData offlineTimelineData;

  TimelineService timelineService;

  TimelineProcessor processor;

  /// Trace events we received while listening to the Timeline event stream.
  ///
  /// This does not include events that we receive while stopped.
  List<TraceEventWrapper> allTraceEvents = [];

  bool get hasStarted => data != null;

  Future<void> selectTimelineEvent(TimelineEvent event) async {
    if (event == null || data.selectedEvent == event) return;

    data.selectedEvent = event;
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
    if (event == null || data.selectedEvent == event) return;
    data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;
  }

  Future<void> getCpuProfileForSelectedEvent() async {
    final selectedEvent = data.selectedEvent;
    if (!selectedEvent.isUiEvent) return;

    await cpuProfilerController.pullAndProcessProfile(
      startMicros: selectedEvent.time.start.inMicroseconds,
      extentMicros: selectedEvent.time.duration.inMicroseconds,
    );
    data.cpuProfileData = cpuProfilerController.dataNotifier.value;
  }

  Future<double> get displayRefreshRate async {
    final refreshRate =
        await serviceManager.getDisplayRefreshRate() ?? defaultRefreshRate;
    data?.displayRefreshRate = refreshRate;
    return refreshRate;
  }

  void selectFrame(TimelineFrame frame) {
    if (frame == null || data.selectedFrame == frame || !hasStarted) {
      return;
    }
    data.selectedFrame = frame;
    _selectedFrameNotifier.value = frame;

    data.selectedEvent = null;
    _selectedTimelineEventNotifier.value = null;
    data.cpuProfileData = null;
    cpuProfilerController.reset();

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
  }

  int vmStartRecordingMicros;
  Future<void> startRecording() async {
    _recordingNotifier.value = true;
    vmStartRecordingMicros =
        (await timelineService.vmTimelineMicros()).timestamp;
    await timelineService.updateListeningState(true);
  }

  Future<void> stopRecording() async {
    _recordingNotifier.value = false;

    if (allTraceEvents.isEmpty) {
      _emptyRecordingNotifier.value = true;
      return;
    }

    _processingNotifier.value = true;
    await processTraceEvents(allTraceEvents);
    _processingNotifier.value = false;
    _timelineProcessedController.add(true);
    await timelineService.updateListeningState(true);
  }

  void addTimelineEvent(TimelineEvent event) {
    data.addTimelineEvent(event);
  }

  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents) async {
    await processor.processTimeline(traceEvents, vmStartRecordingMicros);
    data.initializeEventGroups();
    if (data.eventGroups.isEmpty) {
      _emptyRecordingNotifier.value = true;
    }
  }

  Future<void> loadOfflineData(OfflineTimelineData offlineData) async {
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
    final uiThreadId = _threadIdForEvent(uiEventName, traceEvents);
    final gpuThreadId = _threadIdForEvent(gpuEventName, traceEvents);

    offlineTimelineData = offlineData.shallowClone();
    data = offlineData.shallowClone();
    processor.primeThreadIds(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
    );
    await processTraceEvents(traceEvents);

    if (data.cpuProfileData != null) {
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
    final offlineData = offlineTimelineData;
    final frameToSelect = offlineData.frames.firstWhere(
      (frame) => frame.id == offlineData.selectedFrameId,
      orElse: () => null,
    );
    if (frameToSelect != null) {
      data.selectedFrame = frameToSelect;
      // TODO(kenz): frames bar chart should listen to this stream and
      // programmatially select the frame from the offline snapshot.
      _selectedFrameNotifier.value = frameToSelect;
    }
    if (offlineData.selectedEvent != null) {
      for (var timelineEvent in data.timelineEvents) {
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

    if (eventToSelect != null) {
      data
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
    await timelineService.updateListeningState(true);
  }

  Future<void> exitOfflineMode() async {
    offlineMode = false;
    await _offlineModeChanged();
  }

  Future<void> clearData() async {
    if (serviceManager.hasConnection) {
      await serviceManager.service.clearVMTimeline();
    }
    allTraceEvents.clear();
    offlineTimelineData = null;
    cpuProfilerController.reset();
    data?.clear();
    processor?.reset();
    _selectedTimelineEventNotifier.value = null;
    _selectedFrameNotifier.value = null;
    _recordingNotifier.value = false;
    _processingNotifier.value = false;
    _emptyRecordingNotifier.value = false;
    _clearController.add(true);
  }

  void recordTrace(Map<String, dynamic> trace) {
    data?.traceEvents?.add(trace);
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
    _clearController.close();
    _loadOfflineDataController.close();
    _nonFatalErrorController.close();
  }
}
