// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member

@TestOn('vm')
import 'package:devtools_app/src/timeline/flutter/timeline_controller.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_model.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:test/test.dart';

import '../support/flutter/timeline_test_data.dart';
import '../support/flutter_test_environment.dart';

Future<void> runTimelineControllerTests(FlutterTestEnvironment env) async {
  TimelineController timelineController;
  env.afterNewSetup = () async {
    timelineController = TimelineController()..data = TimelineData();
  };

  group('TimelineController', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('recordTraceForTimelineEvent', () async {
      await env.setupEnvironment();

      expect(timelineController.data.traceEvents, isEmpty);
      timelineController.recordTraceForTimelineEvent(goldenUiTimelineEvent);
      expect(
        timelineController.data.traceEvents,
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

    test('processOfflineData', () async {
      await env.setupEnvironment();

      final offlineTimelineData =
          OfflineTimelineData.parse(offlineTimelineDataJson);
      await timelineController.processOfflineData(offlineTimelineData);
      expect(
        isTimelineDataEqual(
          timelineController.data,
          offlineTimelineData,
        ),
        isTrue,
      );
      expect(
        isTimelineDataEqual(
          timelineController.offlineTimelineData,
          offlineTimelineData,
        ),
        isTrue,
      );
      expect(timelineController.processor.uiThreadId, equals(testUiThreadId));
      expect(timelineController.processor.rasterThreadId,
          equals(testRasterThreadId));

      await env.tearDownEnvironment();
    });

    test('frame selection', () async {
      await env.setupEnvironment();

      // Select a frame.
      expect(timelineController.data.selectedFrame, isNull);
      timelineController.selectFrame(testFrame0);
      expect(
        timelineController.data.selectedFrame,
        equals(testFrame0),
      );

      // Select a timeline event.
      expect(timelineController.data.selectedEvent, isNull);
      expect(timelineController.data.cpuProfileData, isNull);
      await timelineController.selectTimelineEvent(vsyncEvent);
      expect(timelineController.data.selectedEvent, equals(vsyncEvent));

      // Select a different frame.
      timelineController.selectFrame(testFrame1);
      expect(
        timelineController.data.selectedFrame,
        equals(testFrame1),
      );
      expect(timelineController.data.selectedEvent, isNull);
      expect(timelineController.data.cpuProfileData, isNull);

      await env.tearDownEnvironment();
    });

    test('add frame', () async {
      await env.setupEnvironment();
      expect(timelineController.data.frames, isEmpty);
      timelineController.addFrame(testFrame1);
      expect(
        timelineController.data.frames.length,
        equals(1),
      );
      await env.tearDownEnvironment();
    });
  });
}

bool isTimelineDataEqual(TimelineData a, TimelineData b) {
  return a.traceEvents == b.traceEvents &&
      a.frames == b.frames &&
      a.selectedFrame == b.selectedFrame &&
      a.selectedEvent.name == b.selectedEvent.name &&
      a.selectedEvent.time == b.selectedEvent.time &&
      a.cpuProfileData == b.cpuProfileData;
}
