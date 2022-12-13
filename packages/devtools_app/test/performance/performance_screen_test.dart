// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/flutter_frames/flutter_frames_chart.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/legacy/event_details.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/legacy/timeline_flame_chart.dart';
import 'package:devtools_app/src/shared/config_specific/import_export/import_export.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../test_infra/test_data/performance.dart';

void main() {
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(PreferencesController, PreferencesController());
  late PerformanceController controller;
  late FakeServiceManager fakeServiceManager;

  Future<void> _setUpServiceManagerWithTimeline(
    Map<String, dynamic> timelineJson,
  ) async {
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson),
      ),
    );
    when(
      fakeServiceManager.errorBadgeManager.errorCountNotifier('performance'),
    ).thenReturn(ValueNotifier<int>(0));
    final app = fakeServiceManager.connectedApp!;
    when(app.initialized).thenReturn(Completer()..complete(true));
    when(app.isDartWebAppNow).thenReturn(false);
    when(app.isFlutterAppNow).thenReturn(true);
    when(app.isProfileBuild).thenAnswer((_) => Future.value(false));
    when(app.flutterVersionNow).thenReturn(
      FlutterVersion.parse((await fakeServiceManager.flutterVersion).json!),
    );
    when(app.isDartCliAppNow).thenReturn(false);
    when(app.isProfileBuildNow).thenReturn(true);
    when(app.isDartWebApp).thenAnswer((_) async => false);
    when(app.isProfileBuild).thenAnswer((_) async => false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(NotificationService, NotificationService());
    setGlobal(OfflineModeController, OfflineModeController());
  }

  Future<void> pumpPerformanceScreen(
    WidgetTester tester, {
    bool runAsync = false,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const PerformanceScreenBody(),
        performance: controller,
      ),
    );
    await tester.pumpAndSettle();

    if (runAsync) {
      // Await a small delay to allow the PerformanceController to complete
      // initialization.
      await Future.delayed(const Duration(seconds: 1));
    }

    expect(find.byType(PerformanceScreenBody), findsOneWidget);
  }

  const windowSize = Size(3000.0, 1000.0);

  group('PerformanceScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      await _setUpServiceManagerWithTimeline(testTimelineJson);
      controller = PerformanceController();
      await controller.initialized;
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      final screen = PerformanceScreen();
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.buildTab),
          performance: controller,
        ),
      );
      expect(find.text('Performance'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(FlutterFramesChart), findsOneWidget);
        expect(
          find.text('Select a frame above to view analysis data.'),
          findsOneWidget,
        );
        expect(find.byType(VisibilityButton), findsOneWidget);
        expect(find.byIcon(Icons.block), findsOneWidget);
        expect(find.text('Performance Overlay'), findsOneWidget);
        expect(find.text('Enhance Tracing'), findsOneWidget);
        expect(find.text('More debugging options'), findsOneWidget);
        expect(find.byIcon(Icons.file_download), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'builds initial content for non-flutter app', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        mockConnectedApp(
          fakeServiceManager.connectedApp!,
          isFlutterApp: false,
          isProfileBuild: false,
          isWebApp: false,
        );
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(FlutterFramesChart), findsNothing);
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        expect(
          find.byKey(TimelineEventsView.emptyTimelineKey),
          findsNothing,
        );
        expect(find.byType(EventDetails), findsOneWidget);
        expect(find.byType(VisibilityButton), findsNothing);
        expect(find.byIcon(Icons.block), findsOneWidget);
        expect(find.text('Performance Overlay'), findsNothing);
        expect(find.text('Enhance Tracing'), findsNothing);
        expect(find.text('More debugging options'), findsNothing);
        expect(find.byIcon(Icons.file_download), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);

        // Verify the state of the splitter.
        final splitFinder = find.byType(Split);
        expect(splitFinder, findsOneWidget);
        final Split splitter = tester.widget(splitFinder);
        expect(splitter.initialFractions[0], equals(0.7));
      });
    });

    group('Performance controls', () {
      testWidgetsWithWindowSize(
          'can expand and collapse flutter frames chart', windowSize,
          (WidgetTester tester) async {
        await tester.runAsync(() async {
          await pumpPerformanceScreen(tester, runAsync: true);
          await tester.pumpAndSettle();

          final chartButtonFinder = find.byType(VisibilityButton);
          expect(chartButtonFinder, findsOneWidget);

          // The flutter frames chart is visible.
          expect(find.byType(FramesChartControls), findsOneWidget);
          expect(
            controller.flutterFramesController.showFlutterFramesChart.value,
            isTrue,
          );

          await tester.tap(chartButtonFinder);
          await tester.pumpAndSettle();

          // The flutter frames chart should no longer be visible.
          expect(find.byType(FramesChartControls), findsNothing);
          expect(
            controller.flutterFramesController.showFlutterFramesChart.value,
            isFalse,
          );

          await tester.tap(chartButtonFinder);
          await tester.pumpAndSettle();

          // The flutter frames chart should be visible again.
          expect(find.byType(FramesChartControls), findsOneWidget);
          expect(
            controller.flutterFramesController.showFlutterFramesChart.value,
            isTrue,
          );
        });
      });

      testWidgetsWithWindowSize('clears timeline on clear', windowSize,
          (WidgetTester tester) async {
        await tester.runAsync(() async {
          await pumpPerformanceScreen(tester, runAsync: true);
          await tester.pumpAndSettle();

          // Ensure the Timeline Events tab is selected.
          final timelineEventsTabFinder = find.text('Timeline Events');
          expect(timelineEventsTabFinder, findsOneWidget);
          await tester.tap(timelineEventsTabFinder);
          await tester.pumpAndSettle();

          expect(
            controller.timelineEventsController.allTraceEvents,
            isNotEmpty,
          );
          expect(find.byType(FlutterFramesChart), findsOneWidget);
          expect(find.byType(TimelineFlameChart), findsOneWidget);
          expect(
            find.byKey(TimelineEventsView.emptyTimelineKey),
            findsNothing,
          );
          expect(find.byType(EventDetails), findsOneWidget);

          await tester.tap(find.byIcon(Icons.block));
          await tester.pumpAndSettle();
          expect(controller.timelineEventsController.allTraceEvents, isEmpty);
          expect(find.byType(FlutterFramesChart), findsOneWidget);
          expect(find.byType(TimelineFlameChart), findsNothing);
          expect(
            find.byKey(TimelineEventsView.emptyTimelineKey),
            findsOneWidget,
          );
          expect(find.byType(EventDetails), findsNothing);
        });
      });

      testWidgetsWithWindowSize('opens enhance tracing overlay', windowSize,
          (WidgetTester tester) async {
        await tester.runAsync(() async {
          await pumpPerformanceScreen(tester, runAsync: true);
          await tester.pumpAndSettle();
          expect(find.text('Enhance Tracing'), findsOneWidget);
          await tester.tap(find.text('Enhance Tracing'));
          await tester.pumpAndSettle();
          expect(
            find.richTextContaining('frame times may be negatively affected'),
            findsOneWidget,
          );
          expect(
            find.richTextContaining(
              'you will need to reproduce activity in your app',
            ),
            findsOneWidget,
          );
          expect(
            find.richTextContaining('Track Widget Builds'),
            findsOneWidget,
          );
          expect(find.richTextContaining('Track Layouts'), findsOneWidget);
          expect(find.richTextContaining('Track Paints'), findsOneWidget);
          expect(find.byType(MoreInfoLink), findsNWidgets(3));
        });
      });

      testWidgetsWithWindowSize(
          'opens more debugging options overlay', windowSize,
          (WidgetTester tester) async {
        await tester.runAsync(() async {
          await pumpPerformanceScreen(tester, runAsync: true);
          await tester.pumpAndSettle();
          expect(find.text('More debugging options'), findsOneWidget);
          await tester.tap(find.text('More debugging options'));
          await tester.pumpAndSettle();
          expect(
            find.richTextContaining(
              'After toggling a rendering layer on/off, '
              'reproduce the activity in your app to see the effects',
            ),
            findsOneWidget,
          );
          expect(find.richTextContaining('Render Clip layers'), findsOneWidget);
          expect(
            find.richTextContaining('Render Opacity layers'),
            findsOneWidget,
          );
          expect(
            find.richTextContaining('Render Physical Shape layers'),
            findsOneWidget,
          );
          expect(
            find.richTextContaining(
              "These debugging options aren't available in profile mode. "
              'To use them, run your app in debug mode.',
            ),
            findsOneWidget,
          );
          expect(find.byType(MoreInfoLink), findsNWidgets(3));
        });
      });

      testWidgetsWithWindowSize(
          'hides warning in debugging options overlay when in debug mode',
          windowSize, (WidgetTester tester) async {
        when(fakeServiceManager.connectedApp!.isProfileBuildNow)
            .thenReturn(false);

        await tester.runAsync(() async {
          await pumpPerformanceScreen(tester, runAsync: true);
          await tester.pumpAndSettle();
          expect(find.text('More debugging options'), findsOneWidget);
          await tester.tap(find.text('More debugging options'));
          await tester.pumpAndSettle();

          expect(
            find.richTextContaining(
              "These debugging options aren't available in profile mode. "
              'To use them, run your app in debug mode.',
            ),
            findsNothing,
          );
        });
      });
    });
  });
}
