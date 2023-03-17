// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed parsed by test runner.
// test-argument:experimentsOn=true
// test-argument:appPath="test/test_infra/fixtures/memory_app"

import 'dart:ui' as ui;

import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_list.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_app/src/shared/ui/search.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

Future<void> _testBasicEval(_EvalTester tester) async {
  await tester.testEval('21 + 34', find.text('55'));
}

Future<void> _testAssignment(_EvalTester tester) async {
  await tester.testEval('DateTime(2023)', find.text('DateTime'));
  await tester.testEval(
    r'var x = $0',
    find.textContaining('Variable x is created '),
  );
  await tester.testEval(
      'x.toString()', find.text("'${DateTime(2023).toString()}'"));
}

Future<void> _testRootIsAccessible(_EvalTester tester) async {
  await tester.tapAndSettle(find.text('MyApp'));
  await tester.tapAndSettle(find.text(ContextMenuButton.text));
  await tester.tapAndSettle(find.textContaining('one instance'));
  await tester.tapAndSettle(find.text('Any'), duration: longPumpDuration);
  await tester.tapAndSettle(find.textContaining('MyApp, retained size '));
  await tester.tester.pump(longPumpDuration);

  await tester.tapAndSettle(find.text('references'));

  await tester.tapAndSettle(find.textContaining('static ('));
  await tester.tapAndSettle(find.text('_List').at(1));
  await tester.tapAndSettle(find.text('Class'));
  expect(
    find.widgetWithText(ConsolePane, 'Root'),
    findsOneWidget,
  );
}

class _EvalTester {
  _EvalTester(this.tester);

  final WidgetTester tester;

  /// Tests if eval returns expected response by searching for response text.
  Future<void> testEval(String expression, Finder expectedResponse) async {
    await tester.tap(find.byType(AutoCompleteSearchField));
    await tester.pump(safePumpDuration);
    await tester.enterText(find.byType(AutoCompleteSearchField), expression);
    await tester.pump(safePumpDuration);
    await _pressEnter();
    await tester.pump(longPumpDuration);

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
  }

  Future<void> switchToSnapshotsAndTakeOne() async {
    await switchToScreen(tester, ScreenMetaData.memory);
    await tester.tap(find.text('Diff Snapshots'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(iconToTakeSnapshot));
    await tester.pump(longPumpDuration);

    // Sort by class
    await tester.tap(find.text('Class'));
    await tester.pumpAndSettle();

    // Select class
    await tester.tap(find.text('MyApp'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(
    Finder finder, {
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await tester.tap(finder);
    await tester.pumpAndSettle(duration);
  }
}
