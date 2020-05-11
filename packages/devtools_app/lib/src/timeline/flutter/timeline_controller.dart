// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../../auto_dispose.dart';
import '../../config_specific/flutter/import_export/import_export.dart';
import '../../config_specific/logger/allowed_error.dart';
import '../../config_specific/logger/logger.dart';
import '../../globals.dart';
import '../../http/http_service.dart';
import '../../profiler/cpu_profile_controller.dart';
import '../../profiler/cpu_profile_service.dart';
import '../../profiler/cpu_profile_transformer.dart';
import '../../profiler/profile_granularity.dart';
import '../../service_manager.dart';
import '../../trace_event.dart';
import '../../ui/fake_flutter/fake_flutter.dart';
import 'timeline_model.dart';
import 'timeline_processor.dart';
import 'timeline_screen.dart';

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
class TimelineController
    with CpuProfilerControllerProviderMixin
    implements DisposableController {
  TimelineController() {
    processor = TimelineProcessor(this);
    _startTimeline();
  }

  final _exportController = ExportController();

  final _cpuProfilerService = CpuProfilerService();

  /// The currently selected timeline event.
  ValueListenable<TimelineEvent> get selectedTimelineEvent =>
      _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent>(null);

  /// The currently selected timeline frame.
  ValueListenable<TimelineFrame> get selectedFrame => _selectedFrameNotifier;
  final _selectedFrameNotifier = ValueNotifier<TimelineFrame>(null);

  /// Whether an empty timeline recording was just recorded.
  ValueListenable<bool> get emptyTimeline => _emptyTimeline;
  final _emptyTimeline = ValueNotifier<bool>(false);

  /// Whether the timeline is currently being recorded.
  ValueListenable<bool> get refreshing => _refreshingNotifier;
  final _refreshingNotifier = ValueNotifier<bool>(false);

  /// Whether the recorded timeline data is currently being processed.
  ValueListenable<bool> get processing => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  // TODO(jacobr): this isn't accurate. Another page of DevTools
  // or a different instance of DevTools could change this value. We need to
  // sync the value with the server like we do for other vm service extensions
  // that we track with the vm service extension manager.
  /// Whether http timeline logging is enabled.
  ValueListenable<bool> get httpTimelineLoggingEnabled =>
      _httpTimelineLoggingEnabledNotifier;
  final _httpTimelineLoggingEnabledNotifier = ValueNotifier<bool>(false);

  // TODO(kenz): change these streams to ValueListenables or remove altogether
  // if we can refactor the FlutterFramesChart to be written with more idiomatic
  // Flutter.

  /// Stream controller that notifies the timeline has been processed.
  Stream<bool> get onTimelineProcessed => _timelineProcessedController.stream;
  final _timelineProcessedController = StreamController<bool>.broadcast();

  /// Stream controller that notifies that offline data was loaded into the
  /// timeline.
  ///
  /// Subscribers to this stream will be responsible for updating the UI for the
  /// new value of [timelineData].
  Stream<OfflineTimelineData> get onLoadOfflineData =>
      _loadOfflineDataController.stream;
  final _loadOfflineDataController =
      StreamController<OfflineTimelineData>.broadcast();

  /// Stream controller that notifies the timeline screen when a non-fatal error
  /// should be logged for the timeline.
  final _nonFatalErrorController = StreamController<String>.broadcast();

  Stream<String> get onNonFatalError => _nonFatalErrorController.stream;

  /// Stream controller that notifies the timeline has been cleared.
  final _clearController = StreamController<bool>.broadcast();

  Stream<bool> get onTimelineCleared => _clearController.stream;

  /// Active timeline data.
  ///
  /// This is the true source of data for the UI. In the case of an offline
  /// import, this will begin as a copy of [offlineTimelineData] (the original
  /// data from the imported file). If any modifications are made while the data
  /// is displayed (e.g. change in selected timeline event, selected frame,
  /// etc.), those changes will be tracked here.
  TimelineData data;

  /// Timeline data loaded via import.
  ///
  /// This is expected to be null when we are not in [offlineMode].
  ///
  /// This will contain the original data from the imported file, regardless of
  /// any selection modifications that occur while the data is displayed. [data]
  /// will start as a copy of offlineTimelineData in this case, and will track
  /// any data modifications that occur while the data is displayed (e.g. change
  /// in selected timeline event, selected frame, etc.).
  TimelineData offlineTimelineData;

  TimelineProcessor processor;

  /// Trace events in the current timeline.
  ///
  /// This list is cleared and repopulated each time "Refresh" is clicked.
  List<TraceEventWrapper> allTraceEvents = [];

  /// Whether the timeline has been started from [timelineService].
  ///
  /// [data] is initialized in [timelineService.startTimeline], where the
  /// timeline recorders are also set (Dart, GC, Embedder).
  bool get hasStarted => data != null;

  void _startTimeline() async {
    await serviceManager.onServiceAvailable;
    unawaited(allowedError(
      _cpuProfilerService.setProfilePeriod(mediumProfilePeriod),
      logError: false,
    ));
    await allowedError(
        serviceManager.service.setVMTimelineFlags(['GC', 'Dart', 'Embedder']));
  }

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
      buf.writeln('\Raster timeline event frame ${frame.id}:');
      frame.rasterEventFlow.format(buf, '  ');
      buf.writeln('\nRaster trace for frame ${frame.id}');
      frame.rasterEventFlow.writeTraceToBuffer(buf);
      log(buf.toString());
    }
  }

  void addFrame(TimelineFrame frame) {
    data.frames.add(frame);
  }

  Future<void> refreshData() async {
    await clearData(clearVmTimeline: false);
    data = serviceManager.connectedApp.isFlutterAppNow
        ? TimelineData(
            displayRefreshRate: await serviceManager.getDisplayRefreshRate())
        : TimelineData();

    _emptyTimeline.value = false;
    _refreshingNotifier.value = true;
    allTraceEvents.clear();
    final timeline = await serviceManager.service.getVMTimeline();
    primeThreadIds(timeline);
    for (final event in timeline.traceEvents) {
      final eventWrapper = TraceEventWrapper(
        TraceEvent(event.json),
        DateTime.now().millisecondsSinceEpoch,
      );
      allTraceEvents.add(eventWrapper);
    }

    _refreshingNotifier.value = false;

    if (allTraceEvents.isEmpty) {
      _emptyTimeline.value = true;
      return;
    }

    _processingNotifier.value = true;
    await processTraceEvents(allTraceEvents);
    _processingNotifier.value = false;
    _timelineProcessedController.add(true);
  }

  void primeThreadIds(vm_service.Timeline timeline) {
    final threadNameEvents = timeline.traceEvents
        .map((event) => TraceEvent(event.json))
        .where((TraceEvent event) {
      return event.name == 'thread_name';
    }).toList();

    // TODO(kenz): Remove this logic once ui/raster distinction changes are
    // available in the engine.
    int uiThreadId;
    int rasterThreadId;
    final threadIdsByName = <String, int>{};

    String uiThreadName;
    String rasterThreadName;
    String platformThreadName;
    for (TraceEvent event in threadNameEvents) {
      final name = event.args['name'];

      // Android: "1.ui (12652)"
      // iOS: "io.flutter.1.ui (12652)"
      // MacOS, Linux, Windows, Dream (g3): "io.flutter.ui (225695)"
      if (name.contains('.ui')) uiThreadName = name;

      // Android: "1.raster (12651)"
      // iOS: "io.flutter.1.raster (12651)"
      // Linux, Windows, Dream (g3): "io.flutter.raster (12651)"
      // MacOS: Does not exist
      // Also look for .gpu here for older versions of Flutter.
      // TODO(kenz): remove check for .gpu name in April 2021.
      if (name.contains('.raster') || name.contains('.gpu')) {
        rasterThreadName = name;
      }

      // Android: "1.platform (22585)"
      // iOS: "io.flutter.1.platform (22585)"
      // MacOS, Linux, Windows, Dream (g3): "io.flutter.platform (22596)"
      if (name.contains('.platform')) platformThreadName = name;

      threadIdsByName[name] = event.threadId;
    }

    if (uiThreadName != null) {
      uiThreadId = threadIdsByName[uiThreadName];
    }

    // MacOS and Flutter apps with platform views do not have a .gpu thread.
    // In these cases, the "Raster" events will come on the .platform thread
    // instead.
    if (rasterThreadName != null) {
      rasterThreadId = threadIdsByName[rasterThreadName];
    } else {
      rasterThreadId = threadIdsByName[platformThreadName];
    }

    if (uiThreadId == null || rasterThreadId == null) {
      logNonFatalError(
          'Could not find UI thread and / or Raster thread from names: '
          '${threadIdsByName.keys}');
    }

    processor.primeThreadIds(
        uiThreadId: uiThreadId, rasterThreadId: rasterThreadId);
  }

  void addTimelineEvent(TimelineEvent event) {
    data.addTimelineEvent(event);
  }

  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents) async {
    await processor.processTimeline(traceEvents);
    data.initializeEventGroups();
    if (data.eventGroups.isEmpty) {
      _emptyTimeline.value = true;
    }
  }

  FutureOr<void> processOfflineData(OfflineTimelineData offlineData) async {
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
    final uiThreadId =
        _threadIdForEvents({uiEventName, uiEventNameOld}, traceEvents);
    final rasterThreadId = _threadIdForEvents({rasterEventName}, traceEvents);

    offlineTimelineData = offlineData.shallowClone();
    data = offlineData.shallowClone();

    // Process offline data.
    processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
    await processTraceEvents(traceEvents);
    if (data.cpuProfileData != null) {
      await cpuProfilerController.transformer
          .processData(offlineTimelineData.cpuProfileData);
    }

    // Set offline data.
    setOfflineData();

    _loadOfflineDataController.add(offlineTimelineData);
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
    final frameToSelect = offlineTimelineData.frames.firstWhere(
      (frame) => frame.id == offlineTimelineData.selectedFrameId,
      orElse: () => null,
    );
    if (frameToSelect != null) {
      data.selectedFrame = frameToSelect;
      // TODO(kenz): frames bar chart should listen to this stream and
      // programmatially select the frame from the offline snapshot.
      _selectedFrameNotifier.value = frameToSelect;
    }
    if (offlineTimelineData.selectedEvent != null) {
      for (var timelineEvent in data.timelineEvents) {
        final eventToSelect = timelineEvent.firstChildWithCondition((event) {
          return event.name == offlineTimelineData.selectedEvent.name &&
              event.time == offlineTimelineData.selectedEvent.time;
        });
        if (eventToSelect != null) {
          data
            ..selectedEvent = eventToSelect
            ..cpuProfileData = offlineTimelineData.cpuProfileData;
          _selectedTimelineEventNotifier.value = eventToSelect;
          break;
        }
      }
    }

    if (offlineTimelineData.cpuProfileData != null) {
      cpuProfilerController.loadOfflineData(offlineTimelineData.cpuProfileData);
    }
  }

  /// Exports the current timeline data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData = _exportController.encode(TimelineScreen.id, data.json);
    return _exportController.downloadFile(encodedData);
  }

  Future<void> toggleHttpRequestLogging(bool state) async {
    await HttpService.toggleHttpRequestLogging(state);
    _httpTimelineLoggingEnabledNotifier.value = state;
  }

  /// Clears the timeline data currently stored by the controller.
  ///
  /// [clearVmTimeline] defaults to true, but should be set to false if you want
  /// to clear the data stored by the controller, but do not want to clear the
  /// data currently stored by the VM.
  Future<void> clearData({bool clearVmTimeline = true}) async {
    if (clearVmTimeline && serviceManager.hasConnection) {
      await serviceManager.service.clearVMTimeline();
      _emptyTimeline.value = true;
    }
    allTraceEvents.clear();
    offlineTimelineData = null;
    cpuProfilerController.reset();
    data?.clear();
    processor?.reset();
    _selectedTimelineEventNotifier.value = null;
    _selectedFrameNotifier.value = null;
    _processingNotifier.value = false;
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
