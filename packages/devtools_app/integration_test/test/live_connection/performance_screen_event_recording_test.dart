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
import 'package:vm_service_protos/vm_service_protos.dart';

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
      expect(
        trackEvents,
        isEmpty,
        reason: trackEvents
            .map((TracePacket p) => p.trackEvent.writeToJson())
            .join('\n'),
      );

      logStatus('Verify Flutter frames have been assigned timeline events');
      // _verifyFlutterFramesHaveTimelineEvents(performanceController);

      // logStatus(
      //   'toggling the Performance Overlay to trigger new Flutter frames',
      // );
      // final performanceOverlayFinder = find.text('Performance Overlay');
      // expect(performanceOverlayFinder, findsOneWidget);
      // await tester.tap(performanceOverlayFinder);
      // await tester.pump(veryLongPumpDuration);

      // logStatus('Refreshing the timeline to load new events');
      // await _refreshTimeline(tester);

      // logStatus('Verifying that we have not recorded new events');
      // final refreshedTrace = List.of(
      //   performanceController
      //       .timelineEventsController.fullPerfettoTrace!.packet,
      //   growable: false,
      // );
      // expect(
      //   refreshedTrace.length,
      //   greaterThan(initialTrace.length),
      //   reason: 'Expeced new events to have been recorded.',
      // );

      // logStatus('Verify new Flutter frames have been assigned timeline events');
      // // Refresh the timeilne one more time to ensure we have collected all
      // // timeline events in the VM's buffer.
      // await _refreshTimeline(tester);
      // _verifyFlutterFramesHaveTimelineEvents(performanceController);
      // await tester.pump(veryLongPumpDuration);
    },
  );
}

Future<void> _refreshTimeline(WidgetTester tester) async {
  await tester.tap(find.byType(RefreshTimelineEventsButton));
  await tester.pump(veryLongPumpDuration);
}

void _verifyFlutterFramesHaveTimelineEvents(
  PerformanceController performanceController,
) {
  final flutterFrames =
      performanceController.flutterFramesController.flutterFrames.value;
  expect(flutterFrames, isNotEmpty);
  for (final frame in flutterFrames) {
    expect(
      frame.timelineEventData.uiEvent,
      isNotNull,
      reason: 'Expected a non-null UI event for frame ${frame.id}.',
    );
    expect(
      frame.timelineEventData.rasterEvent,
      isNotNull,
      reason: 'Expected a non-null Raster event for frame ${frame.id}.',
    );
  }
}
