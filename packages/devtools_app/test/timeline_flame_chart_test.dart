// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_app/src/charts/flame_chart.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_screen.dart';
import 'package:devtools_app/src/performance/timeline_flame_chart.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import 'support/mocks.dart';
import 'support/performance_test_data.dart';
import 'support/wrappers.dart';

void main() {
  FakeServiceManager fakeServiceManager;
  PerformanceController controller;

  group('TimelineFlameChartContent', () {
    void _setUpServiceManagerWithTimeline(
      Map<String, dynamic> timelineJson,
    ) {
      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          timelineData: vm_service.Timeline.parse(timelineJson),
        ),
      );
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
      when(fakeServiceManager.connectedApp.isProfileBuild)
          .thenAnswer((_) => Future.value(true));
      when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
          .thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
    }

    setUp(() async {
      _setUpServiceManagerWithTimeline(testTimelineJson);
    });

    Future<void> pumpTimelineBody(
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

    testWidgetsWithWindowSize('builds header content', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        _setUpServiceManagerWithTimeline({});
        await pumpTimelineBody(tester);
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
        _setUpServiceManagerWithTimeline({});
        await pumpTimelineBody(tester);
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
        await pumpTimelineBody(tester, runAsync: true);
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
            findsNothing);
      });
    });

    testWidgetsWithWindowSize('builds flame chart with no data', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        _setUpServiceManagerWithTimeline({});
        await pumpTimelineBody(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(TimelineFlameChart), findsNothing);
        expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
            findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'builds flame chart with selected frame', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpTimelineBody(tester, runAsync: true);
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
