// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/flutter/split.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter/event_details.dart';
import 'package:devtools_app/src/timeline/flutter/flutter_frames_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_model.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_screen.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_controller.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:devtools_testing/support/flutter/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  TimelineScreen screen;
  TimelineController controller;
  FakeServiceManager fakeServiceManager;

  Future<void> pumpTimelineScreen(
    WidgetTester tester, {
    TimelineController timelineController,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      const TimelineScreenBody(),
      timeline: controller = timelineController ?? TimelineController(),
    ));
    expect(find.byType(TimelineScreenBody), findsOneWidget);
  }

  Future<void> pumpTimelineWithData(WidgetTester tester) async {
    final data = TimelineData()
      ..timelineEvents.addAll([goldenUiTimelineEvent])
      ..traceEvents.addAll(
          goldenUiTraceEvents.map((eventWrapper) => eventWrapper.event.json))
      ..time.start = goldenUiTimelineEvent.time.start
      ..time.end = goldenUiTimelineEvent.time.end;
    data.initializeEventGroups();
    final controllerWithData = TimelineController()
      ..allTraceEvents.addAll(goldenUiTraceEvents)
      ..data = data
      ..selectFrame(testFrame1);
    await pumpTimelineScreen(
      tester,
      timelineController: controllerWithData,
    );
  }

  const windowSize = Size(2050.0, 1000.0);

  group('TimelineScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
      when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
          .thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      screen = const TimelineScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        timeline: TimelineController(),
      ));
      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgets('builds disabled message when disabled for web app',
        (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(true);
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(TimelineScreenBody), findsNothing);
      expect(find.byType(DisabledForWebAppMessage), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds initial content', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsOneWidget);
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byKey(TimelineScreen.recordButtonKey), findsOneWidget);
      expect(find.byKey(TimelineScreen.stopRecordingButtonKey), findsOneWidget);
      expect(
        find.byKey(TimelineScreen.recordingInstructionsKey),
        findsOneWidget,
      );

      // Verify the state of the splitter.
      final splitFinder = find.byType(Split);
      expect(splitFinder, findsOneWidget);
      final Split splitter = tester.widget(splitFinder);
      expect(splitter.initialFractions[0], equals(0.6));
    });

    testWidgetsWithWindowSize('starts and stops recording', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester);

      // Verify initial state.
      expect(
        find.byKey(TimelineScreen.recordingInstructionsKey),
        findsOneWidget,
      );
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsNothing);
      expect(controller.recording.value, isFalse);

      // Start recording.
      await tester.tap(find.byKey(TimelineScreen.recordButtonKey));
      await tester.pump();
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsOneWidget);
      expect(controller.recording.value, isTrue);

      // Stop recording.
      await tester.tap(find.byKey(TimelineScreen.stopRecordingButtonKey));
      await tester.pump();
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsNothing);
      expect(
        find.byKey(TimelineScreen.emptyTimelineRecordingKey),
        findsOneWidget,
      );
      expect(controller.recording.value, isFalse);
    });

    testWidgetsWithWindowSize('clears timeline on clear', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineWithData(tester);
      expect(controller.allTraceEvents, isNotEmpty);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsOneWidget);
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byType(EventDetails), findsOneWidget);

      await tester.tap(find.byKey(TimelineScreen.clearButtonKey));
      await tester.pump();
      expect(controller.allTraceEvents, isEmpty);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsOneWidget);
      expect(
          find.byKey(TimelineScreen.recordingInstructionsKey), findsOneWidget);
      expect(find.byType(EventDetails), findsOneWidget);
    });

    testWidgetsWithWindowSize('records empty timeline', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester);
      expect(
          find.byKey(TimelineScreen.recordingInstructionsKey), findsOneWidget);
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsNothing);
      expect(
        find.byKey(TimelineScreen.emptyTimelineRecordingKey),
        findsNothing,
      );

      // Record empty timeline.
      await tester.tap(find.byKey(TimelineScreen.recordButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(TimelineScreen.stopRecordingButtonKey));
      await tester.pump();
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsNothing);
      expect(
        find.byKey(TimelineScreen.emptyTimelineRecordingKey),
        findsOneWidget,
      );
    });
  });
}
