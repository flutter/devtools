// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
@TestOn('vm')
import 'package:devtools/src/timeline/timeline_controller.dart';
import 'package:devtools/src/timeline/timeline_model.dart';
import 'package:test/test.dart';

import 'support/flutter_test_driver.dart';
import 'support/flutter_test_environment.dart';
import 'support/timeline_test_data.dart';

void main() {
  group('TimelineController', () {
    TimelineController timelineController;

    final env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    env.afterNewSetup = () async {
      timelineController = TimelineController();
      await timelineController.timelineService.startTimeline();
    };

    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('selection', () async {
      await env.setupEnvironment();

      // Select a frame.
      final frame_0 = TimelineFrame('id_0');
      expect(timelineController.timelineData.selectedFrame, isNull);
      timelineController.selectFrame(frame_0);
      expect(timelineController.timelineData.selectedFrame, equals(frame_0));

      // Select a timeline event.
      expect(timelineController.timelineData.selectedEvent, isNull);
      expect(timelineController.timelineData.cpuProfileData, isNull);
      timelineController.selectTimelineEvent(vsyncEvent);
      expect(timelineController.timelineData.selectedEvent, equals(vsyncEvent));

      // Select a different frame.
      final frame_1 = TimelineFrame('id_1');
      timelineController.selectFrame(frame_1);
      expect(timelineController.timelineData.selectedFrame, equals(frame_1));
      expect(timelineController.timelineData.selectedEvent, isNull);
      expect(timelineController.timelineData.cpuProfileData, isNull);

      await env.tearDownEnvironment();
    });

    test('add frame', () async {
      await env.setupEnvironment();
      expect(timelineController.timelineData.frames, isEmpty);
      timelineController.addFrame(TimelineFrame('id'));
      expect(timelineController.timelineData.frames.length, equals(1));
      await env.tearDownEnvironment();
    });

    test('recordTraceForTimelineEvent', () async {
      await env.setupEnvironment();

      expect(timelineController.timelineData.traceEvents, isEmpty);
      timelineController.recordTraceForTimelineEvent(goldenUiTimelineEvent);
      expect(
        timelineController.timelineData.traceEvents,
        equals([
          vsyncJson,
          animatorBeginFrameJson,
          frameworkWorkloadJson,
          engineBeginFrameJson,
          frameJson,
          animateJson,
          layoutJson,
          buildJson,
          compositingBitsJson,
          paintJson,
          compositingJson,
          semanticsJson,
          finalizeTreeJson,
          endEngineBeginFrameJson,
          endFrameworkWorkloadJson,
          endAnimatorBeginFrameJson,
          endVsyncJson,
        ]),
      );

      await env.tearDownEnvironment();
    });

    test('loadOfflineData', () async {
      await env.setupEnvironment();

      final offlineData = OfflineTimelineData.parse(offlineTimelineDataJson);
      timelineController.loadOfflineData(offlineData);
      expect(
        isTimelineDataEqual(timelineController.timelineData, offlineData),
        isTrue,
      );
      expect(
        isTimelineDataEqual(
            timelineController.offlineTimelineData, offlineData),
        isTrue,
      );
      expect(
        timelineController.timelineProtocol.uiThreadId,
        equals(testUiThreadId),
      );
      expect(
        timelineController.timelineProtocol.gpuThreadId,
        equals(testGpuThreadId),
      );

      await env.tearDownEnvironment();
    });
  }, tags: 'useFlutterSdk');
}

bool isTimelineDataEqual(TimelineData a, TimelineData b) {
  return a.traceEvents == b.traceEvents &&
      a.frames == b.frames &&
      a.selectedFrame == b.selectedFrame &&
      a.selectedEvent == b.selectedEvent &&
      a.cpuProfileData == b.cpuProfileData;
}
