// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/trace_event.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../test_data/performance.dart';

void main() async {
  initializeLiveTestWidgetsFlutterBindingWithAssets();

  late PerformanceController performanceController;
  final ServiceConnectionManager fakeServiceManager = FakeServiceManager(
    service: FakeServiceManager.createFakeService(
      timelineData: vm_service.Timeline.parse(testTimelineJson)!,
    ),
  );

  group('PerformanceController', () {
    setUpAll(() {
      when(fakeServiceManager.connectedApp!.isProfileBuild)
          .thenAnswer((realInvocation) => Future.value(false));
      final initializedCompleter = Completer<bool>();
      initializedCompleter.complete(true);
      when(fakeServiceManager.connectedApp!.initialized)
          .thenReturn(initializedCompleter);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
    });

    setUp(() async {
      setGlobal(OfflineModeController, OfflineModeController());
      performanceController = PerformanceController()..data = PerformanceData();
      await performanceController.initialized;
      // This flag should never be turned on in production.
      expect(debugSimpleTrace, isFalse);
    });

    test(
      'processOfflineData',
      () async {
        offlineController.enterOfflineMode();
        final offlinePerformanceData =
            OfflinePerformanceData.parse(offlinePerformanceDataJson);
        await performanceController.processOfflineData(offlinePerformanceData);
        expect(
          isPerformanceDataEqual(
            performanceController.data!,
            offlinePerformanceData,
          ),
          isTrue,
        );
        expect(
          isPerformanceDataEqual(
            performanceController.offlinePerformanceData!,
            offlinePerformanceData,
          ),
          isTrue,
        );
        expect(
          performanceController.processor.uiThreadId,
          equals(testUiThreadId),
        );
        expect(
          performanceController.processor.rasterThreadId,
          equals(testRasterThreadId),
        );
        expect(
          performanceController.displayRefreshRate.value,
          equals(offlinePerformanceData.displayRefreshRate),
        );
      },
      timeout: const Timeout.factor(8),
    );

    test('frame selection', () async {
      final frame0 = testFrame0.shallowCopy()
        ..setEventFlow(goldenUiTimelineEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      final frame1UiEvent = goldenUiTimelineEvent.deepCopy();
      final frame1RasterEvent = goldenRasterTimelineEvent.deepCopy();
      final frame1 = testFrame1.shallowCopy()
        ..setEventFlow(frame1UiEvent)
        ..setEventFlow(frame1RasterEvent);

      // Select a frame.
      final data = performanceController.data!;

      expect(data.selectedFrame, isNull);
      await performanceController.toggleSelectedFrame(frame0);
      expect(
        data.selectedFrame,
        equals(frame0),
      );
      // Verify main UI event for the frame is selected automatically.
      expect(
        data.selectedEvent,
        equals(goldenUiTimelineEvent),
      );
      expect(data.cpuProfileData, isNotNull);

      // Select another timeline event.
      await performanceController.selectTimelineEvent(animatorBeginFrameEvent);
      expect(data.selectedEvent, equals(animatorBeginFrameEvent));

      // Select a different frame.
      await performanceController.toggleSelectedFrame(frame1);
      expect(
        data.selectedFrame,
        equals(frame1),
      );
      expect(
        data.selectedEvent,
        equals(frame1UiEvent),
      );
      expect(data.cpuProfileData, isNotNull);
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
      expect(
        frame.timeFromEventFlows.start,
        equals(const Duration(microseconds: 5000)),
      );
      expect(
        frame.timeFromEventFlows.end,
        equals(const Duration(microseconds: 8000)),
      );
    });

    test('add frame', () async {
      await performanceController.clearData();

      final data = performanceController.data!;
      expect(data.frames, isEmpty);
      performanceController.addFrame(testFrame1);
      expect(
        data.frames.length,
        equals(1),
      );
    });

    test('matchesForSearch', () async {
      // Verify an empty list is returned for bad input.
      expect(performanceController.matchesForSearch(''), isEmpty);

      await performanceController.clearData();
      expect(performanceController.data!.timelineEvents, isEmpty);
      expect(performanceController.matchesForSearch('test'), isEmpty);

      performanceController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());
      expect(performanceController.matchesForSearch('test'), isEmpty);

      final matches = performanceController.matchesForSearch('frame');
      expect(matches.length, equals(4));
      expect(matches[0].name, equals('Animator::BeginFrame'));
      expect(matches[1].name, equals('Framework Workload'));
      expect(matches[2].name, equals('Engine::BeginFrame'));
      expect(matches[3].name, equals('Frame'));
    });

    test('search query searches through previous matches', () async {
      await performanceController.clearData();
      performanceController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());

      final data = performanceController.data!;

      performanceController.search = 'fram';
      var matches = performanceController.searchMatches.value;
      expect(matches.length, equals(4));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        data.timelineEvents,
        matches,
      );

      // Add another timeline event to verify that this event is not searched
      // for matches.
      performanceController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());

      performanceController.search = 'frame';
      matches = performanceController.searchMatches.value;
      expect(matches.length, equals(4));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        data.timelineEvents,
        matches,
      );

      // Verify that more matches are found without `searchPreviousMatches` set
      // to true.
      performanceController.search = '';
      performanceController.search = 'frame';
      matches = performanceController.searchMatches.value;
      expect(matches.length, equals(8));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        data.timelineEvents,
        matches,
      );
    });
  });
}

bool isPerformanceDataEqual(PerformanceData a, PerformanceData b) {
  return a.traceEvents == b.traceEvents &&
      a.frames == b.frames &&
      a.selectedFrame == b.selectedFrame &&
      a.selectedEvent!.name == b.selectedEvent!.name &&
      a.selectedEvent!.time == b.selectedEvent!.time &&
      a.cpuProfileData == b.cpuProfileData;
}
