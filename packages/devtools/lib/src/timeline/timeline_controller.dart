// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

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

    final TimelineData timelineData =
        TimelineData(uiThreadId: uiThreadId, gpuThreadId: gpuThreadId);

    timelineData.onFrameCompleted.listen((frame) {
      _frameAddedController.add(frame);
    });

    _timelineData = timelineData;
  }
}
