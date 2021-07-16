// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_model.dart';
import 'package:devtools_app/src/trace_event.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_testing/support/flutter_test_driver.dart'
    show FlutterRunConfiguration;
import 'package:devtools_testing/support/flutter_test_environment.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/performance_test_data.dart';
import 'support/utils.dart';

void main() async {
  initializeLiveTestWidgetsFlutterBindingWithAssets();

  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  PerformanceController performanceController;
  env.afterNewSetup = () async {
    performanceController = PerformanceController()..data = PerformanceData();
    await performanceController.initialized;
  };

  group('PerformanceController', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('processOfflineData', () async {
      await env.setupEnvironment();
      offlineMode = true;
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

      final frame0 = testFrame0.shallowCopy()
        ..setEventFlow(goldenUiTimelineEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      final frame1UiEvent = goldenUiTimelineEvent.deepCopy();
      final frame1RasterEvent = goldenRasterTimelineEvent.deepCopy();
      final frame1 = testFrame1.shallowCopy()
        ..setEventFlow(frame1UiEvent)
        ..setEventFlow(frame1RasterEvent);

      // Select a frame.
      expect(performanceController.data.selectedFrame, isNull);
      await performanceController.toggleSelectedFrame(frame0);
      expect(
        performanceController.data.selectedFrame,
        equals(frame0),
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
      await performanceController.toggleSelectedFrame(frame1);
      expect(
        performanceController.data.selectedFrame,
        equals(frame1),
      );
      expect(
        performanceController.data.selectedEvent,
        equals(frame1UiEvent),
      );
      expect(performanceController.data.cpuProfileData, isNotNull);

      await env.tearDownEnvironment();
    });

    test(
        'UI event flow sets frame.timeFromEventFlows end time if it completes after raster event flow',
        () {
      final uiEvent = goldenUiTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 5000)
          ..end = const Duration(microseconds: 8000));
      final rasterEvent = goldenRasterTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 6000)
          ..end = const Duration(microseconds: 7000));

      final frame = FlutterFrame.parse({
        'number': 1,
        'startTime': 100,
        'elapsed': 200,
        'build': 40,
        'raster': 50,
        'vsyncOverhead': 10,
      });
      frame.setEventFlow(rasterEvent, type: TimelineEventType.raster);
      expect(frame.timeFromEventFlows.start, isNull);
      expect(frame.timeFromEventFlows.end, isNull);

      frame.setEventFlow(uiEvent, type: TimelineEventType.ui);
      expect(frame.timeFromEventFlows.start,
          equals(const Duration(microseconds: 5000)));
      expect(frame.timeFromEventFlows.end,
          equals(const Duration(microseconds: 8000)));
    });

    test('add frame', () async {
      await env.setupEnvironment();
      await performanceController.clearData();
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

      await performanceController.clearData();
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

      await performanceController.clearData();
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
