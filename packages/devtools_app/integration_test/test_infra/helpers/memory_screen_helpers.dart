// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/control/primary_controls.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_list.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// / Prepares the UI of the memory screen so that the eval-related elements are
// / visible on the screen for testing.
Future<void> prepareMemoryUI(
  WidgetTester tester, {
  bool closeBannerWarning = true,
  bool collapseChart = true,
  bool makeConsoleWider = false,
  bool openDiff = true,
}) async {
  // Open memory screen.
  await switchToScreen(
    tester,
    tabIcon: ScreenMetaData.memory.icon!,
    screenId: ScreenMetaData.memory.id,
  );

  if (closeBannerWarning) {
    await tapAndPumpWidget(
      tester,
      find.descendant(
        of: find.byType(BannerWarning),
        matching: find.byIcon(Icons.close),
      ),
    );
  }

  if (collapseChart) {
    await tapAndPumpWidget(tester, find.text(PrimaryControls.memoryChartText));
  }

  if (makeConsoleWider) {
    // The distance is big enough to see more items in console,
    // but not too big to make classes in snapshot hidden.
    const dragDistance = -320.0;
    await tester.drag(
      find.byType(ConsolePaneHeader),
      const Offset(0, dragDistance),
    );
    await tester.pumpAndSettle();
  }

  // For the sake of this test, do not show extension screens by default.
  preferences.devToolsExtensions.showOnlyEnabledExtensions.value = true;
  await tester.pumpAndSettle(shortPumpDuration);

  if (openDiff) {
    // Switch to diff tab.
    await tapAndPumpWidget(tester, find.text('Diff Snapshots'));
  }
}

Future<void> takeHeapSnapshot(
  WidgetTester tester,
) async {
  logStatus('Started taking snapshot.');
  // Take snapshot.
  const snapshotDuration = Duration(seconds: 20);
  await tapAndPumpWidget(
    tester,
    find.byIcon(iconToTakeSnapshot),
    duration: snapshotDuration,
  );
  logStatus('Finished taking snapshot.');

  // Sort by class.
  await tapAndPumpWidget(tester, find.text('Class'));

  // Select class.
  await tapAndPumpWidget(tester, find.text('MyApp'));
}

/// Taps and settles.
///
/// If [next] is provided, will repeat the tap until [next] returns results.
/// Returns [next].
Future<Finder?> tapAndPumpWidget(
  WidgetTester tester,
  Finder finder, {
  Duration? duration,
  Finder? next,
  String? description,
}) async {
  Future<void> action(int tryNumber) async {
    logStatus('\nattempt #$tryNumber, tapping');
    logStatus(description ?? finder.toString());
    tryNumber++;
    await tester.tap(finder);
    await tester.pump(duration);
    await tester.pumpAndSettle();
  }

  await action(0);

  if (next == null) return null;

  // These tries are needed because tap in console is flaky.
  for (var tryNumber = 1; tryNumber < 10; tryNumber++) {
    try {
      final items = tester.widgetList(next);
      if (items.isNotEmpty) return next;
      await action(tryNumber);
    } on StateError {
      // tester.widgetList throws StateError if no widgets found.
      await action(tryNumber);
    }
  }

  throw StateError('Could not find $next');
}
