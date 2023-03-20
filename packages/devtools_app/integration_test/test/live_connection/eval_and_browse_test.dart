// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed parsed by test runner.
// test-argument:appPath="test/test_infra/fixtures/memory_app"
// test-argument:experimentsOn=true

import 'dart:ui' as ui;

import 'package:devtools_app/src/screens/memory/panes/control/primary_controls.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_list.dart';
import 'package:devtools_app/src/shared/banner_messages.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_app/src/shared/ui/search.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/eval_and_browse_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() async {
    // This is required to have multiple test cases in this file.
    await (ui.window as dynamic).resetHistory();
  });

  testWidgets('memory eval and browse', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    final evalTester = _EvalTester(tester);

    // await _testBasicEval(evalTester);
    // await _testAssignment(evalTester);

    await evalTester.switchToSnapshotsAndTakeOne();

    await _testRootIsAccessible(evalTester);
  });
}

Future<void> _testRootIsAccessible(_EvalTester tester) async {
  await tester.tapAndPump(find.text('MyApp'));
  await tester.tapAndPump(find.text(ContextMenuButton.text));
  await tester.tapAndPump(find.textContaining('one instance'));
  await tester.tapAndPump(find.text('Any'), duration: longPumpDuration);

  Finder next = find.textContaining('MyApp, retained size ');
  next = await tester.tapAndPump(next, next: find.text('references'));
  next = await tester.tapAndPump(next, next: find.textContaining('static ('));
  next = await tester.tapAndPump(next, next: find.text('inbound'));
  next = await tester.tapAndPump(
    next,
    next: find.text('_List'),
    at: 1,
  ); // Second in the list
  next = await tester.tapAndPump(
    next,
    next: find.text('Class'),
    at: 1,
  ); // Second after column name

  await tester.tapAndPump(next, next: find.text('Root'));
}

class _EvalTester {
  _EvalTester(this.tester);

  final WidgetTester tester;

  /// Tests if eval returns expected response by searching for response text.
  Future<void> testEval(String expression, Finder expectedResponse) async {
    await tapAndPump(find.byType(AutoCompleteSearchField));
    await tester.enterText(find.byType(AutoCompleteSearchField), expression);
    await tester.pump(safePumpDuration);
    await _pressEnter();

    try {
      expect(expectedResponse, findsOneWidget);
    } catch (e) {
      // In case of unexpected response take golden for troubleshooting.
      print(e.toString());
      await expectLater(
        find.byType(ConsolePane),
        matchesGoldenFile('debug_golden.png'),
      );
    }
  }

  Future<void> _pressEnter() async {
    // TODO(polina-c): Figure out why one time sometimes is not enough.
    // https://github.com/flutter/devtools/issues/5436
    await simulateKeyDownEvent(LogicalKeyboardKey.enter);
    await simulateKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await simulateKeyDownEvent(LogicalKeyboardKey.enter);
    await simulateKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(longPumpDuration);
  }

  Future<void> switchToSnapshotsAndTakeOne() async {
    // Open memory screen.
    await switchToScreen(tester, ScreenMetaData.memory);

    // Close warning and chart to get screen.
    await tapAndPump(find.byKey(DebugModeMemoryMessage.closeKey));
    await tapAndPump(find.text(PrimaryControls.memoryChartText));

    // Increase cinsole.
    await tester.drag(
      find.byKey(ConsolePaneHeader.theKey),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    // Switch to diff tab.
    await tapAndPump(find.text('Diff Snapshots'));

    logStatus('Started taking snapshot.');
    // Take snapshot.
    const snapshotDuration = Duration(seconds: 20);
    await tapAndPump(
      find.byIcon(iconToTakeSnapshot),
      duration: snapshotDuration,
    );
    logStatus('Finished taking snapshot.');

    // Sort by class.
    await tapAndPump(find.text('Class'));

    // Select class.
    await tapAndPump(find.text('MyApp'));
  }

  /// Taps and settles.
  ///
  /// If [next] is provided, will repeat the tap till [next] combined with [at] returns results.
  /// If [next] is not null returns [next]  combined with [at, otherwise returns [finder].
  Future<Finder> tapAndPump(
    Finder finder, {
    Duration? duration,
    Finder? next,
    int at = 0,
  }) async {
    int tryNumber = 0;

    Future<void> action() async {
      logStatus("tapping #$tryNumber to find $at'th item in the finder\n"
          '[$finder]\n');
      tryNumber++;
      await tester.tap(finder);
      await tester.pump(duration);
      await tester.pumpAndSettle();
    }

    await action();

    if (next == null) return finder;

    // Tthese tries are needed because tap in console is flaky.
    while (tryNumber < 10) {
      try {
        final items = tester.widgetList(next);
        if (at < items.length) return next.at(at);
        await action();
      } on StateError {
        await action();
      }
    }
    throw 'Cound not find $next';
  }
}
