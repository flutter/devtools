// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed by test runner.
// test-argument:appPath="test/test_infra/fixtures/memory_app"
// test-argument:experimentsOn=true

// ignore_for_file: avoid_print

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run the test while connected to a flutter-tester device:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/eval_and_inspect_test.dart

// To run the test while connected to a chrome device:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/eval_and_inspect_test.dart --test-app-device=chrome

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() async {
    await resetHistory();
  });

  testWidgets('eval and browse in inspector window', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    final evalTester = _EvalAndBrowseTester(tester);
    await evalTester.prepareInspectorUI();

    await _testBasicEval(evalTester);
    await _testAssignment(evalTester);
    await _testEvalOnWidgetTreeNode(evalTester);
  });
}

Future<void> _testBasicEval(_EvalAndBrowseTester tester) async {
  await tester.testEval('21 + 34', find.text('55'));
}

Future<void> _testAssignment(_EvalAndBrowseTester tester) async {
  await tester.testEval('DateTime(2023)', find.text('DateTime'));
  await tester.testEval(
    r'var x = $0',
    find.textContaining('Variable x is created '),
  );
  await tester.testEval(
    'x.toString()',
    find.text("'${DateTime(2023).toString()}'"),
  );
}

Future<void> _testEvalOnWidgetTreeNode(_EvalAndBrowseTester tester) async {
  await tester.selectWidgetTreeNode(find.richText('FloatingActionButton'));
  await tester.testEval(
    r'var x = $0',
    find.textContaining('Variable x is created '),
  );
  await tester.testEval(
    'x.toString()',
    find.textContaining('FloatingActionButton(tooltip: "Increment"'),
  );
}

class _EvalAndBrowseTester {
  _EvalAndBrowseTester(this.tester);

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
      const goldenName = 'debug_golden.png';
      // In case of unexpected response take golden for troubleshooting.
      logStatus('Unexpected response. Taking $goldenName.\n$e');
      await expectLater(
        find.byType(ConsolePane),
        matchesGoldenFile(goldenName),
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

  /// Prepares the UI of the memory screen so that the eval-related elements are
  /// visible on the screen for testing.
  Future<void> prepareInspectorUI() async {
    // Open the inspector screen.
    await switchToScreen(tester, ScreenMetaData.inspector);
    await tester.pumpAndSettle();
  }

  /// Selects a widget to run evaluation on.
  Future<void> selectWidgetTreeNode(Finder finder) async {
    await tapAndPump(
      find.descendant(
        of: find.byKey(InspectorScreenBodyState.summaryTreeKey),
        matching: finder,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps and settles.
  ///
  /// If [next] is provided, will repeat the tap until [next] returns results.
  /// If [next] is not null returns [next].
  Future<Widget?> tapAndPump(
    Finder finder, {
    Duration? duration,
    Finder? next,
  }) async {
    Future<void> action(int tryNumber) async {
      logStatus('attempt #$tryNumber, tapping \n[$finder]\n');
      tryNumber++;
      await tester.tap(finder);
      await tester.pump(duration);
      await tester.pumpAndSettle();
    }

    await action(0);

    if (next == null) return null;

    // These tries are needed because tap in the console is flaky.
    for (var tryNumber = 1; tryNumber < 10; tryNumber++) {
      try {
        final items = tester.widgetList(next);
        if (items.isNotEmpty) return items.first;
        await action(tryNumber);
      } on StateError {
        // tester.widgetList throws StateError if no widgets found.
        await action(tryNumber);
      }
    }

    throw StateError('Could not find $next');
  }
}
