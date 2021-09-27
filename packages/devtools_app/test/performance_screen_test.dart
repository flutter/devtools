// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/performance/event_details.dart';
import 'package:devtools_app/src/performance/flutter_frames_chart.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_screen.dart';
import 'package:devtools_app/src/performance/timeline_flame_chart.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import 'package:devtools_app/test_helpers/mocks.dart';
import 'package:devtools_app/test_helpers/performance_test_data.dart';
import 'package:devtools_app/test_helpers/wrappers.dart';

void main() {
  PerformanceScreen screen;
  PerformanceController controller;
  FakeServiceManager fakeServiceManager;

  void _setUpServiceManagerWithTimeline(Map<String, dynamic> timelineJson) {
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson),
      ),
    );
    when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
        .thenReturn(ValueNotifier<int>(0));
    when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
        .thenReturn(false);
    when(fakeServiceManager.connectedApp.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
    setGlobal(ServiceConnectionManager, fakeServiceManager);
  }

  Future<void> pumpPerformanceScreen(
    WidgetTester tester, {
    PerformanceController performanceController,
    bool runAsync = false,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      const PerformanceScreenBody(),
      performance: controller =
          performanceController ?? PerformanceController(),
    ));
    await tester.pumpAndSettle();

    if (runAsync) {
      // Await a small delay to allow the PerformanceController to complete
      // initialization.
      await Future.delayed(const Duration(seconds: 1));
    }

    expect(find.byType(PerformanceScreenBody), findsOneWidget);
  }

  const windowSize = Size(2050.0, 1000.0);

  group('PerformanceScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      _setUpServiceManagerWithTimeline(testTimelineJson);
      screen = const PerformanceScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        performance: PerformanceController(),
      ));
      expect(find.text('Performance'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(FlutterFramesChart), findsOneWidget);
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
            findsNothing);
        expect(find.byType(EventDetails), findsOneWidget);
        expect(find.byType(PauseButton), findsOneWidget);
        expect(find.byType(ResumeButton), findsOneWidget);
        expect(find.byType(ClearButton), findsOneWidget);

        // Verify the state of the splitter.
        final splitFinder = find.byType(Split);
        expect(splitFinder, findsOneWidget);
        final Split splitter = tester.widget(splitFinder);
        expect(splitter.initialFractions[0], equals(0.7));
      });
    });

    testWidgetsWithWindowSize(
        'builds initial content for empty timeline', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        _setUpServiceManagerWithTimeline({});
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(FlutterFramesChart), findsOneWidget);
        expect(find.byType(TimelineFlameChart), findsNothing);
        expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
            findsOneWidget);
        expect(find.byType(EventDetails), findsOneWidget);
        expect(find.byType(PauseButton), findsOneWidget);
        expect(find.byType(ResumeButton), findsOneWidget);
        expect(find.byType(ClearButton), findsOneWidget);

        // Verify the state of the splitter.
        final splitFinder = find.byType(Split);
        expect(splitFinder, findsOneWidget);
        final Split splitter = tester.widget(splitFinder);
        expect(splitter.initialFractions[0], equals(0.7));
      });
    });

    testWidgetsWithWindowSize(
        'can pause and resume frame recording', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(PauseButton), findsOneWidget);
        expect(find.byType(ResumeButton), findsOneWidget);

        expect(controller.recordingFrames.value, isTrue);
        await tester.tap(find.byType(PauseButton));
        await tester.pumpAndSettle();
        expect(controller.recordingFrames.value, isFalse);
        await tester.tap(find.byType(ResumeButton));
        await tester.pumpAndSettle();
        expect(controller.recordingFrames.value, isTrue);
      });
    });

    testWidgetsWithWindowSize('clears timeline on clear', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(controller.allTraceEvents, isNotEmpty);
        expect(find.byType(FlutterFramesChart), findsOneWidget);
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
            findsNothing);
        expect(find.byType(EventDetails), findsOneWidget);

        await tester.tap(find.byType(ClearButton));
        await tester.pumpAndSettle();
        expect(controller.allTraceEvents, isEmpty);
        expect(find.byType(FlutterFramesChart), findsOneWidget);
        expect(find.byType(TimelineFlameChart), findsNothing);
        expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
            findsOneWidget);
        expect(find.byType(EventDetails), findsOneWidget);
      });
    });
  });
}
