// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member

@TestOn('vm')
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_model.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:test/test.dart';

import 'support/flutter_test_environment.dart';
import 'support/performance_test_data.dart';

Future<void> runPerformanceControllerTests(FlutterTestEnvironment env) async {
  PerformanceController performanceController;
  env.afterNewSetup = () async {
    performanceController = PerformanceController()..data = PerformanceData();
    await performanceController.initialized;
  };

  group('PerformanceController', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('recordTraceForTimelineEvent', () async {
      await env.setupEnvironment();

      expect(performanceController.data.traceEvents, isEmpty);
      performanceController.recordTraceForTimelineEvent(goldenUiTimelineEvent);
      expect(
        performanceController.data.traceEvents,
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
          OfflinePerformanceData.parse(offlinePerformanceDataJson);
      await performanceController.processOfflineData(offlineTimelineData);
      expect(
        isPerformanceDataEqual(
          performanceController.data,
          offlineTimelineData,
        ),
        isTrue,
      );
      expect(
        isPerformanceDataEqual(
          performanceController.offlinePerformanceData,
          offlineTimelineData,
        ),
        isTrue,
      );
      expect(
          performanceController.processor.uiThreadId, equals(testUiThreadId));
      expect(performanceController.processor.rasterThreadId,
          equals(testRasterThreadId));

      await env.tearDownEnvironment();
    });

    test('frame selection', () async {
      await env.setupEnvironment();

      // Select a frame.
      expect(performanceController.data.selectedFrame, isNull);
      await performanceController.toggleSelectedFrame(testFrame0);
      expect(
        performanceController.data.selectedFrame,
        equals(testFrame0),
      );
      // Verify main UI event for the frame is selected automatically.
      expect(
        performanceController.data.selectedEvent,
        equals(goldenUiTimelineEvent),
      );
      expect(performanceController.data.cpuProfileData, isNotNull);

      // Select another timeline event.
      await performanceController.selectTimelineEvent(animatorBeginFrameEvent);
      expect(performanceController.data.selectedEvent,
          equals(animatorBeginFrameEvent));

      // Select a different frame.
      await performanceController.toggleSelectedFrame(testFrame1);
      expect(
        performanceController.data.selectedFrame,
        equals(testFrame1),
      );
      expect(
        performanceController.data.selectedEvent,
        equals(goldenUiTimelineEvent),
      );
      expect(performanceController.data.cpuProfileData, isNotNull);

      await env.tearDownEnvironment();
    });

    test('add frame', () async {
      await env.setupEnvironment();
      expect(performanceController.data.frames, isEmpty);
      performanceController.addFrame(testFrame1);
      expect(
        performanceController.data.frames.length,
        equals(1),
      );
      await env.tearDownEnvironment();
    });

    test('matchesForSearch', () async {
      await env.setupEnvironment();

      // Verify an empty list is returned for bad input.
      expect(performanceController.matchesForSearch(null), isEmpty);
      expect(performanceController.matchesForSearch(''), isEmpty);

      await performanceController.clearData(clearVmTimeline: false);
      expect(performanceController.data.timelineEvents, isEmpty);
      expect(performanceController.matchesForSearch('test'), isEmpty);

      performanceController.addTimelineEvent(goldenUiTimelineEvent);
      expect(performanceController.matchesForSearch('test'), isEmpty);

      final matches = performanceController.matchesForSearch('frame');
      expect(matches.length, equals(4));
      expect(matches[0].name, equals('Animator::BeginFrame'));
      expect(matches[1].name, equals('Framework Workload'));
      expect(matches[2].name, equals('Engine::BeginFrame'));
      expect(matches[3].name, equals('Frame'));

      await env.tearDownEnvironment();
    });

    test('matchesForSearch sets isSearchMatch property', () async {
      await env.setupEnvironment();

      await performanceController.clearData(clearVmTimeline: false);
      performanceController.addTimelineEvent(goldenUiTimelineEvent);
      var matches = performanceController.matchesForSearch('frame');
      expect(matches.length, equals(4));
      verifyIsSearchMatch(performanceController.data.timelineEvents, matches);

      matches = performanceController.matchesForSearch('begin');
      expect(matches.length, equals(2));
      verifyIsSearchMatch(performanceController.data.timelineEvents, matches);

      await env.tearDownEnvironment();
    });
  });
}

bool isPerformanceDataEqual(PerformanceData a, PerformanceData b) {
  return a.traceEvents == b.traceEvents &&
      a.frames == b.frames &&
      a.selectedFrame == b.selectedFrame &&
      a.selectedEvent.name == b.selectedEvent.name &&
      a.selectedEvent.time == b.selectedEvent.time &&
      a.cpuProfileData == b.cpuProfileData;
}

// TODO(kenz): this is copied from devtools_app/test/support/utils.dart. We
// should re-evaluate the purpose of the devtools_testing package and move some
// of these tests back into the main devtools_app package if possible.
void verifyIsSearchMatch(
    List<DataSearchStateMixin> data,
    List<DataSearchStateMixin> matches,
    ) {
  for (final request in data) {
    if (matches.contains(request)) {
      expect(request.isSearchMatch, isTrue);
    } else {
      expect(request.isSearchMatch, isFalse);
    }
  }
}
