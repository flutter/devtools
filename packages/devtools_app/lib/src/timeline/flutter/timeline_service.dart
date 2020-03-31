// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../config_specific/logger/allowed_error.dart';
import '../../globals.dart';
import '../../profiler/cpu_profile_service.dart';
import '../../profiler/profile_granularity.dart';
import '../../trace_event.dart';
import '../../vm_service_wrapper.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

/// Manages interactions between the Timeline and the VmService.
class TimelineService {
  TimelineService(this.timelineController) {
    _initListeners();
  }

  final TimelineController timelineController;

  final profilerService = CpuProfilerService();

  Future<Timestamp> vmTimelineMicros() async {
    return await serviceManager.service.getVMTimelineMicros();
  }

  void _initListeners() async {
    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    // Do not start the timeline for Dart web apps.
    if (serviceManager.hasConnection &&
        !await serviceManager.connectedApp.isDartWebApp) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

    timelineController.recording.addListener(() => updateListeningState(true));
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    allowedError(
      profilerService.setProfilePeriod(mediumProfilePeriod),
      logError: false,
    );
    serviceManager.service.onEvent('Timeline').listen((Event event) {
      final List<dynamic> list = event.json['timelineEvents'];
      final List<Map<String, dynamic>> events =
          list.cast<Map<String, dynamic>>();

      if (!offlineMode && timelineController.recording.value) {
        for (Map<String, dynamic> json in events) {
          final eventWrapper = TraceEventWrapper(
            TraceEvent(json),
            DateTime.now().millisecondsSinceEpoch,
          );
          timelineController.allTraceEvents.add(eventWrapper);
        }
      }
    });
  }

  void _handleConnectionStop(dynamic event) {
    // TODO(kenz): investigate if we need to do anything here.
  }

  Future<void> startTimeline() async {
    timelineController.data = await serviceManager.connectedApp.isFlutterApp
        ? TimelineData(
            displayRefreshRate: await serviceManager.getDisplayRefreshRate(),
          )
        : TimelineData();

    await serviceManager.serviceAvailable.future;
    await allowedError(serviceManager.service
        .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']));
    await allowedError(serviceManager.service.clearVMTimeline());

    final timeline = await serviceManager.service.getVMTimeline();
    final List<dynamic> list = timeline.json['traceEvents'];
    final List<Map<String, dynamic>> traceEvents =
        list.cast<Map<String, dynamic>>();

    final List<TraceEvent> events = traceEvents
        .map((Map<String, dynamic> event) => TraceEvent(event))
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
    for (TraceEvent event in events) {
      final name = event.args['name'];

      // Android: "1.ui (12652)"
      // iOS: "io.flutter.1.ui (12652)"
      // MacOS, Linux, Windows, Dream (g3): "io.flutter.ui (225695)"
      if (name.contains('.ui')) uiThreadName = name;

      // Android: "1.gpu (12651)"
      // iOS: "io.flutter.1.gpu (12651)"
      // Linux, Windows, Dream (g3): "io.flutter.gpu (12651)"
      // MacOS: Does not exist
      if (name.contains('.gpu')) rasterThreadName = name;

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
      timelineController.logNonFatalError(
          'Could not find UI thread and / or Raster thread from names: '
          '${threadIdsByName.keys}');
    }

    timelineController.processor
        .primeThreadIds(uiThreadId: uiThreadId, rasterThreadId: rasterThreadId);
  }

  Future<void> updateListeningState(bool isCurrentScreen) async {
    final bool shouldBeRunning =
        timelineController.recording.value && !offlineMode && isCurrentScreen;
    final bool isRunning = serviceManager.serviceAvailable.isCompleted &&
        timelineController.recording.value &&
        (await serviceManager.service.getVMTimelineFlags())
            .recordedStreams
            .isNotEmpty;

    await serviceManager.serviceAvailable.future;
    if (shouldBeRunning) {
      await startTimeline();
    } else if (shouldBeRunning && !isRunning) {
      await allowedError(serviceManager.service
          .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']));
    } else if (!shouldBeRunning && isRunning) {
      await allowedError(serviceManager.service.setVMTimelineFlags(<String>[]));
    }
  }
}
