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
  // Max number of frames we should store and display in the UI.
  final int maxFrames = 120;

  final StreamController<TimelineFrame> _frameAddedController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;
  final StreamController<Null> _framesClearedController =
      StreamController<Null>.broadcast();
  Stream<Null> get onFramesCleared => _framesClearedController.stream;

  // Timeline data.
  final List<TimelineEvent> dartEvents = <TimelineEvent>[];
  final List<TimelineEvent> gpuEvents = <TimelineEvent>[];

  TimelineData _timelineData;
  TimelineData get timelineData => _timelineData;

  bool get hasStarted => timelineData != null;

  bool _paused = false;
  bool get paused => _paused;

  void pause() {
    _paused = true;

    dartEvents.clear();
    gpuEvents.clear();
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

    // TODO(kenzie): Remove this logic once cpu/gpu distinction changes are
    // available in the engine.
    int cpuThreadId;
    int gpuThreadId;
    for (TraceEvent event in events) {
      if (event.args['name'].startsWith('io.flutter.1.ui')) {
        cpuThreadId = event.threadId;
      }
      if (event.args['name'].startsWith('io.flutter.1.gpu')) {
        gpuThreadId = event.threadId;
      }
    }

    // TODO(kenzie): to preserve memory, remove oldest frame from timelineData
    //  once we reach our max number of frames.
    final TimelineData timelineData =
        TimelineData(cpuThreadId: cpuThreadId, gpuThreadId: gpuThreadId);

    timelineData.onFrameCompleted.listen((frame) {
      _frameAddedController.add(frame);
    });

    _timelineData = timelineData;
  }
}
