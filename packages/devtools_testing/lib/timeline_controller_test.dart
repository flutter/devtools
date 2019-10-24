// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member

@TestOn('vm')
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:test/test.dart';

import 'support/flutter_test_environment.dart';
import 'support/timeline_test_data.dart';

Future<void> runTimelineControllerTests(FlutterTestEnvironment env) async {
  TimelineController timelineController;
  env.afterNewSetup = () async {
    timelineController = TimelineController();
    await timelineController.timelineService.startTimeline();
  };

  group('TimelineController', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('recordTraceForTimelineEvent', () async {
      await env.setupEnvironment();

      expect(timelineController.timelineData.traceEvents, isEmpty);
      timelineController.recordTraceForTimelineEvent(goldenUiTimelineEvent);
      expect(
        timelineController.timelineData.traceEvents,
        equals([
          vsyncTrace.json,
          animatorBeginFrameTrace.json,
          frameworkWorkloadTrace.json,
          engineBeginFrameTrace.json,
          frameTrace.json,
          animateTrace.json,
          layoutTrace.json,
          buildTrace.json,
          compositingBitsTrace.json,
          paintTrace.json,
          compositingTrace.json,
          semanticsTrace.json,
          finalizeTreeTrace.json,
          endEngineBeginFrameTrace.json,
          endFrameworkWorkloadTrace.json,
          endAnimatorBeginFrameTrace.json,
          endVsyncTrace.json,
        ]),
      );

      await env.tearDownEnvironment();
    });

    test('loadOfflineData', () async {
      await env.setupEnvironment();

      // Frame based timeline.
      final offlineFrameBasedTimelineData = OfflineFrameBasedTimelineData.parse(
          offlineFrameBasedTimelineDataJson);
      timelineController.loadOfflineData(offlineFrameBasedTimelineData);
      expect(
        isFrameBasedTimelineDataEqual(
          timelineController.timelineData,
          offlineFrameBasedTimelineData,
        ),
        isTrue,
      );
      expect(
        isFrameBasedTimelineDataEqual(
          timelineController.offlineTimelineData,
          offlineFrameBasedTimelineData,
        ),
        isTrue,
      );
      expect(
        timelineController.frameBasedTimeline.processor.uiThreadId,
        equals(testUiThreadId),
      );
      expect(
        timelineController.frameBasedTimeline.processor.gpuThreadId,
        equals(testGpuThreadId),
      );

      // Full timeline.
      final offlineFullTimelineData =
          OfflineFullTimelineData.parse(offlineFullTimelineDataJson);
      timelineController.loadOfflineData(offlineFullTimelineData);
      expect(timelineController.timelineMode, equals(TimelineMode.full));
      expect(
        isFullTimelineDataEqual(
          timelineController.offlineTimelineData,
          offlineFullTimelineData,
        ),
        isTrue,
      );
      expect(
        timelineController.fullTimeline.processor.uiThreadId,
        equals(testUiThreadId),
      );
      expect(
        timelineController.fullTimeline.processor.gpuThreadId,
        equals(testGpuThreadId),
      );

      await env.tearDownEnvironment();
    });
  });

  group('FrameBasedTimeline', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('selection', () async {
      await env.setupEnvironment();

      // Select a frame.
      final frame_0 = TimelineFrame('id_0');
      expect(timelineController.frameBasedTimeline.data.selectedFrame, isNull);
      timelineController.frameBasedTimeline.selectFrame(frame_0);
      expect(
        timelineController.frameBasedTimeline.data.selectedFrame,
        equals(frame_0),
      );

      // Select a timeline event.
      expect(timelineController.timelineData.selectedEvent, isNull);
      expect(timelineController.timelineData.cpuProfileData, isNull);
      timelineController.selectTimelineEvent(vsyncEvent);
      expect(timelineController.timelineData.selectedEvent, equals(vsyncEvent));

      // Select a different frame.
      final frame_1 = TimelineFrame('id_1');
      timelineController.frameBasedTimeline.selectFrame(frame_1);
      expect(
        timelineController.frameBasedTimeline.data.selectedFrame,
        equals(frame_1),
      );
      expect(timelineController.timelineData.selectedEvent, isNull);
      expect(timelineController.timelineData.cpuProfileData, isNull);

      await env.tearDownEnvironment();
    });

    test('add frame', () async {
      await env.setupEnvironment();
      expect(timelineController.frameBasedTimeline.data.frames, isEmpty);
      timelineController.frameBasedTimeline.addFrame(TimelineFrame('id'));
      expect(
        timelineController.frameBasedTimeline.data.frames.length,
        equals(1),
      );
      await env.tearDownEnvironment();
    });
  });

  group('FullTimeline', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('recording', () {
      expect(timelineController.fullTimeline.recording, isFalse);
      timelineController.fullTimeline.startRecording();
      expect(timelineController.fullTimeline.recording, isTrue);
      timelineController.fullTimeline.stopRecording();
      expect(timelineController.fullTimeline.recording, isFalse);
    });
  });
}

bool isFrameBasedTimelineDataEqual(
  FrameBasedTimelineData a,
  FrameBasedTimelineData b,
) {
  return a.traceEvents == b.traceEvents &&
      a.frames == b.frames &&
      a.selectedFrame == b.selectedFrame &&
      a.selectedEvent == b.selectedEvent &&
      a.cpuProfileData == b.cpuProfileData;
}

bool isFullTimelineDataEqual(
  FullTimelineData a,
  FullTimelineData b,
) {
  return a.traceEvents == b.traceEvents &&
      a.selectedEvent == b.selectedEvent &&
      a.cpuProfileData == b.cpuProfileData;
}
