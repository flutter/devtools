// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/split.dart';
import 'package:devtools_app/src/timeline/event_details.dart';
import 'package:devtools_app/src/timeline/flutter_frames_chart.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_app/src/timeline/timeline_flame_chart.dart';
import 'package:devtools_app/src/timeline/timeline_screen.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  TimelineScreen screen;
  TimelineController controller;
  FakeServiceManager fakeServiceManager;

  void _setUpServiceManagerForTimeline(Map<String, dynamic> timelineJson) {
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson),
      ),
    );
    when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
        .thenReturn(false);
    when(fakeServiceManager.connectedApp.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
    setGlobal(ServiceConnectionManager, fakeServiceManager);
  }

  Future<void> pumpTimelineScreen(
    WidgetTester tester, {
    TimelineController timelineController,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      const TimelineScreenBody(),
      timeline: controller = timelineController ?? TimelineController(),
    ));
    // Delay to ensure the timeline has started.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(TimelineScreenBody), findsOneWidget);
  }

  const windowSize = Size(2050.0, 1000.0);

  group('TimelineScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      _setUpServiceManagerForTimeline(testTimelineJson);
      screen = const TimelineScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        timeline: TimelineController(),
      ));
      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester);
      await tester.pumpAndSettle();
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
          findsNothing);
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(RefreshButton), findsOneWidget);
      expect(find.byType(ClearButton), findsOneWidget);

      // Verify the state of the splitter.
      final splitFinder = find.byType(Split);
      expect(splitFinder, findsOneWidget);
      final Split splitter = tester.widget(splitFinder);
      expect(splitter.initialFractions[0], equals(0.6));
    });

    testWidgetsWithWindowSize('clears timeline on clear', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester);
      await tester.pumpAndSettle();
      expect(controller.allTraceEvents, isNotEmpty);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
          findsNothing);
      expect(find.byType(EventDetails), findsOneWidget);

      await tester.tap(find.byType(ClearButton));
      await tester.pump();
      expect(controller.allTraceEvents, isEmpty);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byType(TimelineFlameChart), findsNothing);
      expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
          findsOneWidget);
      expect(find.byType(EventDetails), findsOneWidget);
    });

    testWidgetsWithWindowSize('refreshes with empty timeline', windowSize,
        (WidgetTester tester) async {
      _setUpServiceManagerForTimeline({});
      await pumpTimelineScreen(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
          findsOneWidget);

      // Refresh with empty timeline.
      await tester.tap(find.byType(RefreshButton));
      await tester.pump();
      expect(find.byKey(TimelineFlameChartContainer.emptyTimelineKey),
          findsOneWidget);
    });
  });
}
