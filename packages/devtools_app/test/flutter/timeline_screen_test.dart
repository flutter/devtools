// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/src/flutter/split.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter/event_details.dart';
import 'package:devtools_app/src/timeline/flutter/flutter_frames_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_flame_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_screen.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  TimelineScreen screen;
  TimelineScreenBodyState state;
  TimelineController controller;
  FakeServiceManager fakeServiceManager;

  Future<void> pumpTimelineScreen(
    WidgetTester tester,
    TimelineMode mode, {
    TimelineController timelineController,
  }) async {
    // Set a wide enough screen width that we do not run into overflow.
    await tester.pumpWidget(wrapWithControllers(
      TimelineScreenBody(),
      timelineController:
          controller = timelineController ?? TimelineController()
            ..selectTimelineMode(mode),
    ));
    expect(find.byType(TimelineScreenBody), findsOneWidget);

    state = tester.state(find.byType(TimelineScreenBody));
    expect(state.controller.timelineModeNotifier.value, equals(mode));
  }

  Future<void> pumpTimelineWithSelectedFrame(WidgetTester tester) async {
    final mockData = MockFrameBasedTimelineData();
    when(mockData.displayDepth).thenReturn(8);
    when(mockData.selectedFrame).thenReturn(testFrame0);
    final controllerWithData = TimelineController()
      ..allTraceEvents.addAll(goldenUiTraceEvents)
      ..frameBasedTimeline.data = mockData
      ..frameBasedTimeline.selectFrame(testFrame1);
    await pumpTimelineScreen(
      tester,
      TimelineMode.frameBased,
      timelineController: controllerWithData,
    );
  }

  const windowSize = Size(1599.0, 1000.0);

  group('TimelineScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      screen = const TimelineScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds proper content for state', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester, TimelineMode.frameBased);

      final splitFinder = find.byType(Split);

      // Verify TimelineMode.frameBased content.
      expect(splitFinder, findsNothing);
      expect(find.byKey(TimelineScreen.pauseButtonKey), findsOneWidget);
      expect(find.byKey(TimelineScreen.resumeButtonKey), findsOneWidget);
      expect(find.byKey(TimelineScreen.recordButtonKey), findsNothing);
      expect(find.byKey(TimelineScreen.stopRecordingButtonKey), findsNothing);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsNothing);
      expect(find.byType(EventDetails), findsNothing);

      // Add a selected frame and ensure the flame chart and event details
      // section appear.
      await pumpTimelineWithSelectedFrame(tester);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsOneWidget);
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byType(EventDetails), findsOneWidget);

      // Switch timeline mode and pump.
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Verify TimelineMode.full content.
      expect(
        state.controller.timelineModeNotifier.value,
        equals(TimelineMode.full),
      );
      expect(find.byKey(TimelineScreen.pauseButtonKey), findsNothing);
      expect(find.byKey(TimelineScreen.resumeButtonKey), findsNothing);
      expect(find.byKey(TimelineScreen.recordButtonKey), findsOneWidget);
      expect(find.byKey(TimelineScreen.stopRecordingButtonKey), findsOneWidget);
      expect(find.byType(FlutterFramesChart), findsNothing);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsOneWidget);
      expect(find.byType(TimelineFlameChart), findsNothing);
      expect(
        find.byKey(TimelineScreen.recordingInstructionsKey),
        findsOneWidget,
      );
      expect(find.byType(EventDetails), findsOneWidget);

      // Verify the state of the splitter.
      expect(splitFinder, findsOneWidget);
      final Split splitter = tester.widget(splitFinder);
      expect(splitter.initialFirstFraction, equals(0.6));
    });

    testWidgetsWithWindowSize('pauses and resumes', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester, TimelineMode.frameBased);

      // Verify initial state.
      expect(controller.frameBasedTimeline.pausedNotifier.value, isFalse);
      expect(controller.frameBasedTimeline.manuallyPaused, isFalse);

      // Pause.
      await tester.tap(find.byKey(TimelineScreen.pauseButtonKey));
      await tester.pump();
      expect(controller.frameBasedTimeline.pausedNotifier.value, isTrue);
      expect(controller.frameBasedTimeline.manuallyPaused, isTrue);

      // Resume.
      await tester.tap(find.byKey(TimelineScreen.resumeButtonKey));
      await tester.pump();
      expect(controller.frameBasedTimeline.pausedNotifier.value, isFalse);
      expect(controller.frameBasedTimeline.manuallyPaused, isFalse);
    });

    testWidgetsWithWindowSize('starts and stops recording', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineScreen(tester, TimelineMode.full);

      // Verify initial state.
      expect(
        find.byKey(TimelineScreen.recordingInstructionsKey),
        findsOneWidget,
      );
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsNothing);
      expect(controller.fullTimeline.recordingNotifier.value, isFalse);

      // Start recording.
      await tester.tap(find.byKey(TimelineScreen.recordButtonKey));
      await tester.pump();
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsOneWidget);
      expect(controller.fullTimeline.recordingNotifier.value, isTrue);

      // Stop recording.
      await tester.tap(find.byKey(TimelineScreen.stopRecordingButtonKey));
      await tester.pump();
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsNothing);
      expect(
        find.byKey(TimelineScreen.emptyTimelineRecordingKey),
        findsOneWidget,
      );
      expect(controller.fullTimeline.recordingNotifier.value, isFalse);
    });

    testWidgetsWithWindowSize('clears timeline on clear', windowSize,
        (WidgetTester tester) async {
      // Clear the frame-based timeline.
      await pumpTimelineWithSelectedFrame(tester);

      expect(controller.allTraceEvents, isNotEmpty);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsOneWidget);
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
      expect(find.byType(EventDetails), findsOneWidget);

      await tester.tap(find.byKey(TimelineScreen.clearButtonKey));
      await tester.pump();
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.flameChartSectionKey), findsNothing);
      expect(find.byType(EventDetails), findsNothing);
      expect(controller.allTraceEvents, isEmpty);

      // Clear the full timeline.
      await pumpTimelineScreen(tester, TimelineMode.full);
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

      await tester.tap(find.byKey(TimelineScreen.clearButtonKey));
      await tester.pump();
      expect(
        find.byKey(TimelineScreen.recordingInstructionsKey),
        findsOneWidget,
      );
      expect(find.byKey(TimelineScreen.recordingStatusKey), findsNothing);
      expect(
        find.byKey(TimelineScreen.emptyTimelineRecordingKey),
        findsNothing,
      );
    });
  });
}
