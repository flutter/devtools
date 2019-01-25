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
  // Frame data.
  static const int maxFrames = 120;
  final List<TimelineFrame> frames = <TimelineFrame>[];
  final StreamController<TimelineFrame> _frameAddedController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;
  final StreamController<Null> _framesClearedController =
      StreamController<Null>.broadcast();
  Stream<Null> get onFramesCleared => _framesClearedController.stream;

  // Timeline data.
  final List<TimelineThreadEvent> dartEvents = <TimelineThreadEvent>[];
  final List<TimelineThreadEvent> gpuEvents = <TimelineThreadEvent>[];

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

    final List<TimelineEvent> events = traceEvents
        .map((Map<String, dynamic> event) => TimelineEvent(event))
        .where((TimelineEvent event) {
      return event.name == 'thread_name';
    }).toList();

    final TimelineData timelineData = TimelineData();

    for (TimelineEvent event in events) {
      final TimelineThread thread =
          TimelineThread(timelineData, event.args['name'], event.threadId);
      // TODO(kenzie): once we have gpu/cpu distinction data from engine, only
      // add the threads that contain those events.
      timelineData.addThread(thread);
    }

    timelineData.onTimelineThreadEvent.listen((TimelineThreadEvent event) {
      processTimelineEvent(timelineData.getThread(event.threadId), event);
    });

    _timelineData = timelineData;
  }

  void processTimelineEvent(TimelineThread thread, TimelineThreadEvent event) {
    if (thread == null) {
      return;
    }

    // TODO(kenzie): once we have gpu/cpu distinction data from engine, use that
    //  information to separate dart events from gpu events. Thread names and
    //  event names are not stable, also rendering us unable to test this logic
    //  in its current state.

    // io.flutter.1.ui, io.flutter.1.gpu
    if (thread.name.endsWith('.ui')) {
      // PipelineProduce
      if (event.name == 'PipelineProduce' && event.wellFormed) {
        dartEvents.add(event);

        _processDataSamples();
      }
    } else if (thread.name.endsWith('.gpu')) {
      // MessageLoop::RunExpiredTasks
      if (event.name == 'MessageLoop::RunExpiredTasks' && event.wellFormed) {
        gpuEvents.add(event);

        _processDataSamples();
      }
    }
  }

  void _processDataSamples() {
    while (dartEvents.isNotEmpty && gpuEvents.isNotEmpty) {
      int dartStart = dartEvents.first.startMicros;

      // TODO(kenzie): improve runtime. Perhaps track an index to the first gpu
      // event to include or check a boolean before adding event to [gpuEvents].

      // Throw away any gpu samples that start before dart ones.
      while (gpuEvents.isNotEmpty && gpuEvents.first.startMicros < dartStart) {
        gpuEvents.removeAt(0);
      }

      if (gpuEvents.isEmpty) {
        break;
      }

      // Find the newest dart sample that starts before a gpu one.
      final int gpuStart = gpuEvents.first.startMicros;
      while (dartEvents.length > 1 &&
          (dartEvents[0].startMicros < gpuStart &&
              dartEvents[1].startMicros < gpuStart)) {
        dartEvents.removeAt(0);
      }

      if (dartEvents.isEmpty) {
        break;
      }

      // Return the pair.
      dartStart = dartEvents.first.startMicros;
      if (dartStart > gpuStart) {
        break;
      }

      final TimelineThreadEvent dartEvent = dartEvents.removeAt(0);
      final TimelineThreadEvent gpuEvent = gpuEvents.removeAt(0);

      final TimelineFrame frame = TimelineFrame(
          renderStart: dartEvent.startMicros,
          rasterizeStart: gpuEvent.startMicros);
      frame.renderDuration = dartEvent.durationMicros;
      frame.rasterizeDuration = gpuEvent.durationMicros;

      frames.add(frame);

      if (frames.length > maxFrames) {
        frames.removeAt(0);
      }

      _frameAddedController.add(frame);
    }
  }
}
