// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart' show Response, Event;
import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../vm_service_wrapper.dart';
import 'cpu_profile_model.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';
import 'timeline_protocol.dart';

/// Manages interactions between the Timeline and the VmService.
class TimelineService {
  TimelineService(this.timelineController) {
    _initListeners();
  }

  final TimelineController timelineController;

  void _initListeners() {
    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    serviceManager.service.setFlag('profile_period', '50');
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
    // TODO(kenzie): investigate if we need to do anything here.
  }

  Future<void> startTimeline() async {
    timelineController.timelineData = TimelineData();

    await serviceManager.serviceAvailable.future;
    await serviceManager.service
        .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    await serviceManager.service.clearVMTimeline();

    final Timeline timeline = await serviceManager.service.getVMTimeline();
    final List<dynamic> list = timeline.json['traceEvents'];
    final List<Map<String, dynamic>> traceEvents =
        list.cast<Map<String, dynamic>>();

    final List<TraceEvent> events = traceEvents
        .map((Map<String, dynamic> event) => TraceEvent(event))
        .where((TraceEvent event) {
      return event.name == 'thread_name';
    }).toList();

    // TODO(kenzie): Remove this logic once ui/gpu distinction changes are
    // available in the engine.
    int uiThreadId;
    int gpuThreadId;
    for (TraceEvent event in events) {
      // iOS - 'io.flutter.1.ui', Android - '1.ui'.
      if (event.args['name'].contains('1.ui')) {
        uiThreadId = event.threadId;
      }
      // iOS - 'io.flutter.1.gpu', Android - '1.gpu'.
      if (event.args['name'].contains('1.gpu')) {
        gpuThreadId = event.threadId;
      }
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
      await serviceManager.service
          .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    } else if (!shouldBeRunning && isRunning) {
      // TODO(devoncarew): turn off the events
      timelineController.pause();
      await serviceManager.service.setVMTimelineFlags(<String>[]);
    }
  }

  Future<CpuProfileData> getCpuProfile({
    @required int startMicros,
    @required int extentMicros,
  }) async {
    final Response response =
        await serviceManager.service.getCpuProfileTimeline(
      serviceManager.isolateManager.selectedIsolate.id,
      startMicros,
      extentMicros,
    );
    return CpuProfileData.parse(response.json);
  }
}
