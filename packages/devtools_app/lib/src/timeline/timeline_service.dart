// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/allowed_error.dart';
import '../globals.dart';
import '../profiler/cpu_profile_service.dart';
import '../vm_service_wrapper.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';
import 'timeline_protocol.dart';

/// Manages interactions between the Timeline and the VmService.
class TimelineService {
  TimelineService(this.timelineController) {
    _initListeners();
  }

  final TimelineController timelineController;

  void _initListeners() async {
    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    // Do not start the timeline for Dart web apps.
    if (serviceManager.hasConnection &&
        !await serviceManager.connectedApp.isDartWebApp) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    allowedError(
      serviceManager.service.setFlag('profile_period', '$defaultSamplePeriod'),
      logError: false,
    );
    serviceManager.service.onEvent('Timeline').listen((Event event) {
      final List<dynamic> list = event.json['timelineEvents'];
      final List<Map<String, dynamic>> events =
          list.cast<Map<String, dynamic>>();

      if (!offlineMode &&
          !timelineController.manuallyPaused &&
          !timelineController.paused) {
        for (Map<String, dynamic> json in events) {
          final TraceEvent e = TraceEvent(json);
          timelineController.timelineProtocol?.processTraceEvent(e);
        }
      }
    });
  }

  void _handleConnectionStop(dynamic event) {
    // TODO(kenz): investigate if we need to do anything here.
  }

  Future<void> startTimeline() async {
    timelineController.timelineData = TimelineData(
      displayRefreshRate: await serviceManager.getDisplayRefreshRate(),
    );

    await serviceManager.serviceAvailable.future;
    await allowedError(serviceManager.service
        .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']));
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

    // Store the thread names for debugging purposes. If [uiThreadId] or
    // [gpuThreadId] are null, we will print all the thread names we received
    // to console.
    final threadNames = [];

    for (TraceEvent event in events) {
      final name = event.args['name'];
      threadNames.add(name);

      // iOS: "io.flutter.1.ui (12652)", Android: "1.ui (12652)",
      // Dream (g3): "io.flutter.ui (12652)"
      if (name.contains('.ui')) {
        uiThreadId = event.threadId;
      }
      // iOS: "io.flutter.1.gpu (12651)", Android: "1.gpu (12651)",
      // Dream (g3): "io.flutter.gpu (12651)"
      if (name.contains('.gpu')) {
        gpuThreadId = event.threadId;
      }
    }

    if (uiThreadId == null || gpuThreadId == null) {
      timelineController.logNonFatalError(
          'Could not find UI thread and / or GPU thread from names: '
          '$threadNames');
    }

    timelineController.timelineProtocol = TimelineProtocol(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
      timelineController: timelineController,
    );
  }

  Future<void> updateListeningState({
    @required bool shouldBeRunning,
    @required bool isRunning,
  }) async {
    await serviceManager.serviceAvailable.future;
    if (shouldBeRunning && isRunning && !timelineController.hasStarted) {
      await startTimeline();
    } else if (shouldBeRunning && !isRunning) {
      timelineController.resume();
      await allowedError(serviceManager.service
          .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']));
    } else if (!shouldBeRunning && isRunning) {
      // TODO(devoncarew): turn off the events
      timelineController.pause();
      await allowedError(serviceManager.service.setVMTimelineFlags(<String>[]));
    }
  }
}
