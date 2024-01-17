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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  testWidgets(
    'refreshing the timeline does not duplicate recorded events',
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
      final initialEventsRecorded =
          List.of(performanceController.data!.traceEvents, growable: false);

      logStatus(
        'toggling the Performance Overlay to trigger new Flutter frames',
      );
      final performanceOverlayFinder = find.text('Performance Overlay');
      expect(performanceOverlayFinder, findsOneWidget);
      await tester.tap(performanceOverlayFinder);
      await tester.pump(safePumpDuration);

      logStatus('Refreshing the timeline to load new events');
      await tester.tap(find.byType(RefreshTimelineEventsButton));
      await tester.pump(longPumpDuration);

      logStatus('Verifying that we have not recorded duplicate events');
      final newEventsRecorded = performanceController.data!.traceEvents
          .sublist(initialEventsRecorded.length);
      for (final newEvent in newEventsRecorded) {
        final eventDuplicated = initialEventsRecorded.containsWhere(
          (event) => collectionEquals(event, newEvent),
        );
        expect(
          eventDuplicated,
          isFalse,
          reason: 'Duplicate event recorded: $newEvent',
        );
      }
    },
  );
}
