// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/allowed_error.dart';
import '../globals.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/profile_granularity.dart';
import '../trace_event.dart';
import '../vm_service_wrapper.dart';
import 'html_timeline_controller.dart';
import 'html_timeline_model.dart';

/// Manages interactions between the Timeline and the VmService.
class TimelineService {
  TimelineService(this.timelineController) {
    _initListeners();
  }

  final TimelineController timelineController;

  final profilerService = CpuProfilerService();

  void _initListeners() async {
    serviceManager.onConnectionAvailable.listen(_initTimelineListener);
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  void _initTimelineListener(VmServiceWrapper service) {
    assert(serviceManager.hasConnection);
    // Do not start the timeline for Dart web apps.
    if (serviceManager.connectedApp.isDartWebAppNow) return;

    allowedError(
      profilerService.setProfilePeriod(mediumProfilePeriod),
      logError: false,
    );
    serviceManager.service.onEvent('Timeline').listen((Event event) {
      final List<dynamic> list = event.json['timelineEvents'];
      final List<Map<String, dynamic>> events =
          list.cast<Map<String, dynamic>>();

      final bool shouldProcessEventForFrameBasedTimeline =
          timelineController.timelineModeNotifier.value ==
                  TimelineMode.frameBased &&
              !timelineController.frameBasedTimeline.manuallyPaused &&
              !timelineController.frameBasedTimeline.pausedNotifier.value;
      final bool shouldProcessEventForFullTimeline =
          timelineController.timelineModeNotifier.value == TimelineMode.full &&
              timelineController.fullTimeline.recordingNotifier.value;

      if (!offlineMode &&
          (shouldProcessEventForFrameBasedTimeline ||
              shouldProcessEventForFullTimeline)) {
        for (Map<String, dynamic> json in events) {
          final eventWrapper = TraceEventWrapper(
            TraceEvent(json),
            DateTime.now().millisecondsSinceEpoch,
          );
          timelineController.allTraceEvents.add(eventWrapper);

          // For [TimelineMode.frameBased], process the events as we receive
          // them.
          if (timelineController.timelineModeNotifier.value ==
              TimelineMode.frameBased) {
            timelineController.frameBasedTimeline.processor
                ?.processTraceEvent(eventWrapper);
          }
        }
      }
    });
  }

  void _handleConnectionStop(dynamic event) {
    // TODO(kenz): investigate if we need to do anything here.
  }

  Future<void> startTimeline() async {
    if (await serviceManager.connectedApp.isFlutterApp) {
      timelineController.frameBasedTimeline.data = FrameBasedTimelineData(
          displayRefreshRate: await serviceManager.getDisplayRefreshRate());
    }
    timelineController.fullTimeline.data = FullTimelineData();

    await serviceManager.serviceAvailable.future;
    await allowedError(
        serviceManager.service.setVMTimelineFlags(['GC', 'Dart', 'Embedder']));
    await allowedError(serviceManager.service.clearVMTimeline());

    final Timeline timeline = await serviceManager.service.getVMTimeline();
    final List<dynamic> list = timeline.json['traceEvents'];
    final List<Map<String, dynamic>> traceEvents =
        list.cast<Map<String, dynamic>>();

    final List<TraceEvent> events = traceEvents
        .map((Map<String, dynamic> event) => TraceEvent(event))
        .where((TraceEvent event) {
      return event.name == 'thread_name';
    }).toList();

    // TODO(kenz): Remove this logic once ui/gpu distinction changes are
    // available in the engine.
    int uiThreadId;
    int gpuThreadId;
    final threadIdsByName = <String, int>{};

    String uiThreadName;
    String gpuThreadName;
    String platformThreadName;
    for (TraceEvent event in events) {
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
        gpuThreadName = name;
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
    // In these cases, the "GPU" events will come on the .platform thread
    // instead.
    if (gpuThreadName != null) {
      gpuThreadId = threadIdsByName[gpuThreadName];
    } else {
      gpuThreadId = threadIdsByName[platformThreadName];
    }

    if (uiThreadId == null || gpuThreadId == null) {
      timelineController.logNonFatalError(
          'Could not find UI thread and / or GPU thread from names: '
          '${threadIdsByName.keys}');
    }

    for (var timeline in timelineController.timelines) {
      timeline.processor
          .primeThreadIds(uiThreadId: uiThreadId, gpuThreadId: gpuThreadId);
    }
  }

  Future<void> updateListeningState(bool isCurrentScreen) async {
    final bool shouldBeRunning =
        (!timelineController.frameBasedTimeline.manuallyPaused ||
                timelineController.fullTimeline.recordingNotifier.value) &&
            !offlineMode &&
            isCurrentScreen;
    final bool isRunning = serviceManager.serviceAvailable.isCompleted &&
        (!timelineController.frameBasedTimeline.pausedNotifier.value ||
            timelineController.fullTimeline.recordingNotifier.value) &&
        (await serviceManager.service.getVMTimelineFlags())
            .recordedStreams
            .isNotEmpty;
    await _updateListeningState(
      shouldBeRunning: shouldBeRunning,
      isRunning: isRunning,
    );
  }

  Future<void> _updateListeningState({
    @required bool shouldBeRunning,
    @required bool isRunning,
  }) async {
    // TODO(kenz): instead of awaiting here, should we check that
    // serviceManager.connectedApp != null?
    await serviceManager.serviceAvailable.future;
    if (shouldBeRunning) {
      await startTimeline();
    } else if (shouldBeRunning && !isRunning) {
      timelineController.frameBasedTimeline.resume();
    } else if (!shouldBeRunning && isRunning) {
      // TODO(devoncarew): turn off the events
      timelineController.frameBasedTimeline.pause();
      await allowedError(serviceManager.service.setVMTimelineFlags([]));
    }
  }
}
