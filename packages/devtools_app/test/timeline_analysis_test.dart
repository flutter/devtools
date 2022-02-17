// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:io';

import 'package:devtools_app/src/charts/flame_chart.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_model.dart';
import 'package:devtools_app/src/performance/performance_screen.dart';
import 'package:devtools_app/src/performance/timeline_analysis.dart';
import 'package:devtools_app/src/performance/timeline_flame_chart.dart';
import 'package:devtools_app/src/primitives/trace_event.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/version.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import 'test_data/performance_test_data.dart';

void main() {
  FakeServiceManager fakeServiceManager;
  PerformanceController controller;

  Future<void> _setUpServiceManagerWithTimeline(
    Map<String, dynamic> timelineJson,
  ) async {
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson),
      ),
    );
    when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp.flutterVersionNow).thenReturn(
        FlutterVersion.parse((await fakeServiceManager.flutterVersion).json));
    when(fakeServiceManager.connectedApp.isProfileBuild)
        .thenAnswer((_) => Future.value(true));
    when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
        .thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(OfflineModeController, OfflineModeController());
    when(serviceManager.connectedApp.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
  }

  group('TimelineAnalysisHeader', () {
    setUp(() async {
      await _setUpServiceManagerWithTimeline(testTimelineJson);
      frameAnalysisSupported = true;
    });

    Future<void> pumpHeader(
      WidgetTester tester, {
      PerformanceController performanceController,
      bool runAsync = false,
    }) async {
      controller = performanceController ?? PerformanceController()
        ..data = PerformanceData();

      if (runAsync) {
        // Await a small delay to allow the PerformanceController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));
      }

      await tester.pumpWidget(
        wrap(
          TimelineAnalysisHeader(
            controller: controller,
            selectedTab: null,
            searchFieldBuilder: () => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize('builds header content', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpHeader(tester);
        await tester.pumpAndSettle();
        expect(find.text('Timeline Events'), findsOneWidget);
        expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'builds header content for selected frame', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});

        // This frame does not have UI jank.
        final frame0 = testFrame0.shallowCopy()
          ..setEventFlow(animatorBeginFrameEvent)
          ..setEventFlow(goldenRasterTimelineEvent);

        controller = PerformanceController()..data = PerformanceData();
        await controller.toggleSelectedFrame(frame0);

        await pumpHeader(tester, performanceController: controller);
        await tester.pumpAndSettle();
        expect(find.text('Timeline Events'), findsOneWidget);
        expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsOneWidget);
        expect(find.byType(AnalyzeFrameButton), findsNothing);
      });
    });

    testWidgetsWithWindowSize(
        'builds header content for selected frame with jank', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});

        // This frame has UI jank.
        final frame0 = jankyFrame.shallowCopy();
        frame0.timelineEventData
          ..setEventFlow(
              event: goldenUiTimelineEvent, type: TimelineEventType.ui)
          ..setEventFlow(
              event: goldenRasterTimelineEvent, type: TimelineEventType.raster);

        controller = PerformanceController()..data = PerformanceData();
        await controller.toggleSelectedFrame(frame0);

        await pumpHeader(tester, performanceController: controller);
        await tester.pumpAndSettle();
        expect(find.text('Timeline Events'), findsOneWidget);
        expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsOneWidget);
        expect(find.byType(AnalyzeFrameButton), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'selecting analyze frame button opens tab', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});

        // This frame has UI jank.
        final frame0 = jankyFrame.shallowCopy();
        frame0.timelineEventData
          ..setEventFlow(
              event: goldenUiTimelineEvent, type: TimelineEventType.ui)
          ..setEventFlow(
              event: goldenRasterTimelineEvent, type: TimelineEventType.raster);

        controller = PerformanceController()..data = PerformanceData();
        await controller.toggleSelectedFrame(frame0);

        await pumpHeader(tester, performanceController: controller);
        await tester.pumpAndSettle();
        expect(find.byType(AnalyzeFrameButton), findsOneWidget);
        expect(controller.selectedAnalysisTab.value, isNull);
        expect(controller.analysisTabs.value, isEmpty);

        await tester.tap(find.byType(AnalyzeFrameButton));
        await tester.pumpAndSettle();

        expect(find.byType(FlutterFrameAnalysisTab), findsOneWidget);
        expect(controller.selectedAnalysisTab.value, isNotNull);
        expect(controller.analysisTabs.value, isNotEmpty);
      });
    });
  });

  group('TimelineAnalysisContainer', () {
    setUp(() async {
      await _setUpServiceManagerWithTimeline(testTimelineJson);
    });

    Future<void> pumpPerformanceScreenBody(
      WidgetTester tester, {
      PerformanceController performanceController,
      bool runAsync = false,
    }) async {
      controller = performanceController ?? PerformanceController();

      if (runAsync) {
        // Await a small delay to allow the PerformanceController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));
      }

      await tester.pumpWidget(wrapWithControllers(
        const PerformanceScreenBody(),
        performance: controller,
      ));
      await tester.pumpAndSettle();
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize('builds header with search field', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpPerformanceScreenBody(tester);
        await tester.pumpAndSettle();
        expect(find.text('Timeline Events'), findsOneWidget);
        expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
        expect(find.byKey(timelineSearchFieldKey), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize('can show help dialog', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpPerformanceScreenBody(tester);
        await tester.pumpAndSettle();

        final helpButtonFinder = find.byType(FlameChartHelpButton);
        expect(helpButtonFinder, findsOneWidget);
        await tester.tap(helpButtonFinder);
        await tester.pumpAndSettle();
        expect(find.text('Flame Chart Help'), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize('builds flame chart with data', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreenBody(tester, runAsync: true);
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        expect(find.byKey(TimelineAnalysisContainer.emptyTimelineKey),
            findsNothing);
      });
    });

    testWidgetsWithWindowSize('builds flame chart with no data', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpPerformanceScreenBody(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(TimelineFlameChart), findsNothing);
        expect(find.byKey(TimelineAnalysisContainer.emptyTimelineKey),
            findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'builds flame chart with selected frame', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreenBody(tester, runAsync: true);
        controller
          ..addFrame(testFrame1.shallowCopy())
          ..addTimelineEvent(goldenUiTimelineEvent)
          ..addTimelineEvent(goldenRasterTimelineEvent);
        expect(controller.data.frames.length, equals(1));
        await controller.toggleSelectedFrame(controller.data.frames.first);
        await tester.pumpAndSettle();
      });
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      await expectLater(
        find.byType(TimelineFlameChart),
        matchesGoldenFile(
            'goldens/timeline_flame_chart_with_selected_frame.png'),
      );
      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }, skip: kIsWeb || !Platform.isMacOS);
  });
}
