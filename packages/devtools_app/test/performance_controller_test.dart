// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

@TestOn('vm')
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/trace_event.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data/performance_test_data.dart';
import 'test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'test_infra/flutter_test_environment.dart';

void main() async {
  initializeLiveTestWidgetsFlutterBindingWithAssets();

  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  PerformanceController performanceController;
  env.afterNewSetup = () async {
    setGlobal(OfflineModeController, OfflineModeController());
    performanceController = PerformanceController()..data = PerformanceData();
    await performanceController.initialized;
  };

  group('PerformanceController', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('processOfflineData', () async {
      await env.setupEnvironment();
      offlineController.enterOfflineMode();
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
      expect(performanceController.matchesForSearch(''), isEmpty);

      await performanceController.clearData();
      expect(performanceController.data.timelineEvents, isEmpty);
      expect(performanceController.matchesForSearch('test'), isEmpty);

      performanceController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());
      expect(performanceController.matchesForSearch('test'), isEmpty);

      final matches = performanceController.matchesForSearch('frame');
      expect(matches.length, equals(4));
      expect(matches[0].name, equals('Animator::BeginFrame'));
      expect(matches[1].name, equals('Framework Workload'));
      expect(matches[2].name, equals('Engine::BeginFrame'));
      expect(matches[3].name, equals('Frame'));

      await env.tearDownEnvironment();
    });

    test('search query searches through previous matches', () async {
      await env.setupEnvironment();

      await performanceController.clearData();
      performanceController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());
      performanceController.search = 'fram';
      var matches = performanceController.searchMatches.value;
      expect(matches.length, equals(4));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        performanceController.data.timelineEvents,
        matches,
      );

      // Add another timeline event to verify that this event is not searched
      // for matches.
      performanceController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());

      performanceController.search = 'frame';
      matches = performanceController.searchMatches.value;
      expect(matches.length, equals(4));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        performanceController.data.timelineEvents,
        matches,
      );

      // Verify that more matches are found without `searchPreviousMatches` set
      // to true.
      performanceController.search = '';
      performanceController.search = 'frame';
      matches = performanceController.searchMatches.value;
      expect(matches.length, equals(8));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        performanceController.data.timelineEvents,
        matches,
      );

      await env.tearDownEnvironment();
    });

    group('Frame analysis', () {
      setUp(() {
        frameAnalysisSupported = true;
      });

      tearDown(() {
        performanceController.clearData();
      });

      tearDownAll(() {
        frameAnalysisSupported = false;
      });

      test('openAnalysisTab opens a new tab and selects it', () async {
        await env.setupEnvironment();

        expect(performanceController.analysisTabs.value, isEmpty);
        expect(performanceController.selectedAnalysisTab.value, isNull);

        performanceController.openAnalysisTab(testFrame0);
        expect(performanceController.analysisTabs.value.length, equals(1));
        expect(performanceController.selectedAnalysisTab.value, isNotNull);
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame0.id));
      });

      test('openAnalysisTab opens an existing tab and selects it', () async {
        await env.setupEnvironment();

        expect(performanceController.analysisTabs.value, isEmpty);
        expect(performanceController.selectedAnalysisTab.value, isNull);

        performanceController.openAnalysisTab(testFrame0);
        expect(performanceController.analysisTabs.value.length, equals(1));
        expect(performanceController.selectedAnalysisTab.value, isNotNull);
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame0.id));

        performanceController.openAnalysisTab(testFrame1);
        expect(performanceController.analysisTabs.value.length, equals(2));
        expect(performanceController.selectedAnalysisTab.value, isNotNull);
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame1.id));

        performanceController.openAnalysisTab(testFrame0);
        expect(performanceController.analysisTabs.value.length, equals(2));
        expect(performanceController.selectedAnalysisTab.value, isNotNull);
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame0.id));
      });

      test('closeAnalysisTab closes a selected tab at index 0', () async {
        await env.setupEnvironment();

        expect(performanceController.analysisTabs.value, isEmpty);
        expect(performanceController.selectedAnalysisTab.value, isNull);

        performanceController.openAnalysisTab(testFrame0);
        performanceController.openAnalysisTab(testFrame1);
        performanceController.openAnalysisTab(testFrame2);
        expect(performanceController.analysisTabs.value.length, equals(3));

        // Re-select frame 0 to select the 0-indexed tab.
        performanceController.openAnalysisTab(testFrame0);

        final firstTab = performanceController.analysisTabs.value[0];
        expect(firstTab.frame.id, equals(testFrame0.id));
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame0.id));

        // Close the first tab (index 0).
        performanceController.closeAnalysisTab(firstTab);

        // The selected tab should now be the next tab.
        expect(performanceController.analysisTabs.value[0].frame.id,
            equals(testFrame1.id));
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame1.id));
      });

      test('closeAnalysisTab closes a selected tab at a non-zero index',
          () async {
        await env.setupEnvironment();

        expect(performanceController.analysisTabs.value, isEmpty);
        expect(performanceController.selectedAnalysisTab.value, isNull);

        performanceController.openAnalysisTab(testFrame0);
        performanceController.openAnalysisTab(testFrame1);
        performanceController.openAnalysisTab(testFrame2);
        expect(performanceController.analysisTabs.value.length, equals(3));

        final lastTab = performanceController.analysisTabs.value[2];
        expect(lastTab.frame.id, equals(testFrame2.id));
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame2.id));

        // Close the last tab (index 2).
        performanceController.closeAnalysisTab(lastTab);

        // The selected tab should now be the previous tab.
        expect(performanceController.analysisTabs.value[1].frame.id,
            equals(testFrame1.id));
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame1.id));
      });

      test('closeAnalysisTab closes a non-selected tab', () async {
        await env.setupEnvironment();

        expect(performanceController.analysisTabs.value, isEmpty);
        expect(performanceController.selectedAnalysisTab.value, isNull);

        performanceController.openAnalysisTab(testFrame0);
        performanceController.openAnalysisTab(testFrame1);
        performanceController.openAnalysisTab(testFrame2);
        expect(performanceController.analysisTabs.value.length, equals(3));

        final firstTab = performanceController.analysisTabs.value[0];
        final lastTab = performanceController.analysisTabs.value[2];
        expect(firstTab.frame.id, equals(testFrame0.id));
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(lastTab.frame.id));

        // Close the first tab (not selected).
        performanceController.closeAnalysisTab(firstTab);

        // The selected tab should still be the last tab.
        expect(performanceController.analysisTabs.value[1].frame.id,
            equals(lastTab.frame.id));
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(lastTab.frame.id));
      });

      test('showTimeline un-selects the selected tab', () async {
        await env.setupEnvironment();

        expect(performanceController.analysisTabs.value, isEmpty);
        expect(performanceController.selectedAnalysisTab.value, isNull);

        performanceController.openAnalysisTab(testFrame0);
        performanceController.openAnalysisTab(testFrame1);
        performanceController.openAnalysisTab(testFrame2);
        expect(performanceController.analysisTabs.value.length, equals(3));

        final lastTab = performanceController.analysisTabs.value[2];
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(lastTab.frame.id));

        // Show the timeline.
        performanceController.showTimeline();

        expect(performanceController.analysisTabs.value.length, equals(3));
        expect(performanceController.selectedAnalysisTab.value, isNull);
      });

      test('selecting a frame un-selects the selected tab', () async {
        await env.setupEnvironment();

        final frame0 = testFrame0.shallowCopy()
          ..setEventFlow(goldenUiTimelineEvent)
          ..setEventFlow(goldenRasterTimelineEvent);

        expect(performanceController.selectedAnalysisTab.value, isNull);
        expect(performanceController.analysisTabs.value, isEmpty);
        performanceController.openAnalysisTab(testFrame0);
        expect(performanceController.analysisTabs.value.length, equals(1));
        expect(performanceController.selectedAnalysisTab.value, isNotNull);
        expect(performanceController.selectedAnalysisTab.value.frame.id,
            equals(testFrame0.id));

        // Select a frame.
        expect(performanceController.data.selectedFrame, isNull);
        await performanceController.toggleSelectedFrame(frame0);
        expect(
          performanceController.data.selectedFrame,
          equals(frame0),
        );

        expect(performanceController.analysisTabs.value.length, equals(1));
        expect(performanceController.selectedAnalysisTab.value, isNull);
      });
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
