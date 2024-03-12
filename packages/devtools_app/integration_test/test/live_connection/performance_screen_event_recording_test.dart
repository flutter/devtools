// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/timeline_events_view.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/performance_screen_event_recording_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  testWidgets(
    'can process and refresh timeline data',
    (tester) async {
      await pumpAndConnectDevTools(tester, testApp);

      logStatus(
        'Open the Performance screen and switch to the Timeline Events tab',
      );

      await switchToScreen(
        tester,
        tabIcon: ScreenMetaData.performance.icon!,
        screenId: ScreenMetaData.performance.id,
      );
      await tester.pump(safePumpDuration);

      await tester.tap(find.widgetWithText(InkWell, 'Timeline Events'));
      await tester.pumpAndSettle(longPumpDuration);

      // Find the [PerformanceController] to access its data.
      final performanceScreenFinder = find.byType(PerformanceScreenBody);
      expect(performanceScreenFinder, findsOneWidget);
      final screenState =
          tester.state<PerformanceScreenBodyState>(performanceScreenFinder);
      final performanceController = screenState.controller;

      logStatus('Verifying that data is processed upon first load');
      final initialTrace = List.of(
        performanceController
            .timelineEventsController.fullPerfettoTrace!.packet,
        growable: false,
      );
      final initialTrackDescriptors =
          initialTrace.where((e) => e.hasTrackDescriptor());
      expect(initialTrace, isNotEmpty);
      expect(initialTrackDescriptors, isNotEmpty);

      final trackEvents = initialTrace.where((e) => e.hasTrackEvent());
      expect(trackEvents, isNotEmpty);

      expect(
        performanceController
            .timelineEventsController.perfettoController.processor.uiTrackId,
        isNotNull,
        reason: 'Expected uiTrackId to be non-null',
      );
      expect(
        performanceController.timelineEventsController.perfettoController
            .processor.rasterTrackId,
        isNotNull,
        reason: 'Expected rasterTrackId to be non-null',
      );
      expect(
        performanceController.timelineEventsController.perfettoController
            .processor.frameRangeFromTimelineEvents,
        isNotNull,
        reason: 'Expected frameRangeFromTimelineEvents to be non-null',
      );

      logStatus(
        'toggling the Performance Overlay to trigger new Flutter frames',
      );
      final performanceOverlayFinder = find.text('Performance Overlay');
      expect(performanceOverlayFinder, findsOneWidget);
      await tester.tap(performanceOverlayFinder);
      await tester.pump(longPumpDuration);

      logStatus('Refreshing the timeline to load new events');
      await tester.tap(find.byType(RefreshTimelineEventsButton));
      await tester.pump(longPumpDuration);

      logStatus('Verifying that we have recorded new events');
      final refreshedTrace = List.of(
        performanceController
            .timelineEventsController.fullPerfettoTrace!.packet,
        growable: false,
      );
      expect(
        refreshedTrace.length,
        greaterThan(initialTrace.length),
        reason: 'Expected new events to have been recorded, but none were.',
      );
    },
  );
}
