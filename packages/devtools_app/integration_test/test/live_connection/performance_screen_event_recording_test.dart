// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/release_notes/release_notes.dart';
import 'package:devtools_app/src/screens/performance/tabbed_performance_view.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_test/devtools_integration_test.dart';
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

  testWidgets('refreshing the timeline does not duplicate recorded events',
      (tester) async {
    await pumpDevTools(tester);
    await connectToTestApp(tester, testApp);

    // If the release notes viewer is open, close it.
    final releaseNotesView =
        tester.widget<ReleaseNotes>(find.byType(ReleaseNotes));
    if (releaseNotesView.releaseNotesController.releaseNotesVisible.value) {
      final closeReleaseNotesButton = find.descendant(
        of: find.byType(ReleaseNotes),
        matching: find.byType(IconButton),
      );
      expect(closeReleaseNotesButton, findsOneWidget);
      await tester.tap(closeReleaseNotesButton);
    }

    logStatus(
      'Open the Performance screen and switch to the Timeline Events tab',
    );
    await tester.tap(
      find.widgetWithText(Tab, ScreenMetaData.performance.title),
    );
    await tester.pump(longPumpDuration);
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

    logStatus('toggling the Performance Overlay to trigger new Flutter frames');
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
  });
}
