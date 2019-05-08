// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../framework/framework.dart';
import '../globals.dart';
import 'timeline_protocol.dart';

/// This class contains the business logic for [timeline.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class TimelineController {
  final StreamController<TimelineFrame> _frameAddedController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;

  TimelineData _timelineData;

  TimelineData get timelineData => _timelineData;

  bool get hasStarted => timelineData != null;

  bool get paused => _paused;

  bool _paused = false;

  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
  }

  Future<void> startTimeline() async {
    await serviceManager.serviceAvailable.future;
    await serviceManager.service
        .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    await serviceManager.service.clearVMTimeline();

    final Response response = await serviceManager.service.getVMTimeline();
    final List<dynamic> list = response.json['traceEvents'];
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

    final TimelineData timelineData = TimelineData(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
    );

    timelineData.onFrameCompleted.listen((frame) {
      if (!importMode) {
        _frameAddedController.add(frame);
      }
    });

    _timelineData = timelineData;
  }

  void loadTimelineFromImport(
    List<TraceEvent> traceEvents,
    Map<String, dynamic> cpuProfile,
  ) {
    // TODO(kenzie): once each trace event has a ui/gpu distinction bit added to
    // the trace, we will not need to infer thread ids. Since we control the
    // format of the input, this is okay for now.
    final uiThreadId = traceEvents.first.threadId;
    final gpuThreadId = traceEvents.last.threadId;

    final TimelineData timelineData = TimelineData(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
    );

    timelineData.onFrameCompleted.listen((frame) {
      // Only add frames from the imported file. If DevTools is already
      // connected to a Flutter app, interacting with the app will attempt to
      // add frames to the timeline. This check prevents us from adding
      // unrelated frames to a timeline import.
      if (importMode && traceEvents.contains(frame.pipelineItemStartTrace)) {
        _frameAddedController.add(frame);
      }
    });

    _timelineData = timelineData;

    for (TraceEvent event in traceEvents) {
      timelineData.processTraceEvent(event, immediate: true);
    }
    // Make a final call to [maybeAddPendingEvents] so that we complete the
    // processing for every frame in the import.
    timelineData.maybeAddPendingEvents();
  }

  void exitImportMode() {
    // If the timeline controller had previously been started, restart it
    // because [_timelineData] has changed since we entered import mode.
    if (hasStarted) {
      startTimeline();
    }
  }
}
