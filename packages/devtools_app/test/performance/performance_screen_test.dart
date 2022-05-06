// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/performance/event_details.dart';
import 'package:devtools_app/src/screens/performance/flutter_frames_chart.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_screen.dart';
import 'package:devtools_app/src/screens/performance/timeline_flame_chart.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_app/src/shared/split.dart';
import 'package:devtools_app/src/shared/version.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../test_data/performance.dart';

void main() {
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(PreferencesController, PreferencesController());
  late PerformanceScreen screen;
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
  }

  Future<void> pumpPerformanceScreen(
    WidgetTester tester, {
    PerformanceController? performanceController,
    bool runAsync = false,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const PerformanceScreenBody(),
        performance: controller =
            performanceController ?? PerformanceController(),
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
      setGlobal(OfflineModeController, OfflineModeController());
      screen = const PerformanceScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.buildTab),
          performance: PerformanceController(),
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
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        expect(
          find.byKey(TimelineEventsView.emptyTimelineKey),
          findsNothing,
        );
        expect(find.byType(EventDetails), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.block), findsOneWidget);
        expect(find.text('Performance Overlay'), findsOneWidget);
        expect(find.text('Enhance Tracing'), findsOneWidget);
        expect(find.text('More debugging options'), findsOneWidget);
        expect(find.byIcon(Icons.file_download), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);

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
        await _setUpServiceManagerWithTimeline({});
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(FlutterFramesChart), findsOneWidget);
        expect(find.byType(TimelineFlameChart), findsNothing);
        expect(
          find.byKey(TimelineEventsView.emptyTimelineKey),
          findsOneWidget,
        );
        expect(find.byType(EventDetails), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.block), findsOneWidget);
        expect(find.text('Performance Overlay'), findsOneWidget);
        expect(find.text('Enhance Tracing'), findsOneWidget);
        expect(find.text('More debugging options'), findsOneWidget);
        expect(find.byIcon(Icons.file_download), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);

        // Verify the state of the splitter.
        final splitFinder = find.byType(Split);
        expect(splitFinder, findsOneWidget);
        final Split splitter = tester.widget(splitFinder);
        expect(splitter.initialFractions[0], equals(0.7));
      });
    });

    testWidgetsWithWindowSize(
        'builds initial content for non-flutter app', windowSize,
        (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp!.isFlutterAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp!.isDartCliAppNow).thenReturn(true);
      await tester.runAsync(() async {
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byType(FlutterFramesChart), findsNothing);
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        expect(
          find.byKey(TimelineEventsView.emptyTimelineKey),
          findsNothing,
        );
        expect(find.byType(EventDetails), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
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

    testWidgetsWithWindowSize(
        'can pause and resume frame recording', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreen(tester, runAsync: true);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);

        expect(controller.recordingFrames.value, isTrue);
        await tester.tap(find.byIcon(Icons.pause));
        await tester.pumpAndSettle();
        expect(controller.recordingFrames.value, isFalse);
        await tester.tap(find.byIcon(Icons.play_arrow));
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
        expect(
          find.byKey(TimelineEventsView.emptyTimelineKey),
          findsNothing,
        );
        expect(find.byType(EventDetails), findsOneWidget);

        await tester.tap(find.byIcon(Icons.block));
        await tester.pumpAndSettle();
        expect(controller.allTraceEvents, isEmpty);
        expect(find.byType(FlutterFramesChart), findsOneWidget);
        expect(find.byType(TimelineFlameChart), findsNothing);
        expect(
          find.byKey(TimelineEventsView.emptyTimelineKey),
          findsOneWidget,
        );
        expect(find.byType(EventDetails), findsOneWidget);
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
        expect(find.richTextContaining('Track Widget Builds'), findsOneWidget);
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
            'you will need to reproduce activity in your app',
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
            'These debugging options aren't available in profile mode. '
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
            'These debugging options aren't available in profile mode. '
            'To use them, run your app in debug mode.',
          ),
          findsNothing,
        );
      });
    });
  });
}
