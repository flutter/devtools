// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed parsed by test runner.
// test-argument:experimentsOn=true
// test-argument:appPath="test/test_infra/fixtures/memory_app"

// ignore_for_file: avoid_print

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
    await resetHistory();
  });

  testWidgets('memory eval and browse', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);

    final evalTester = _EvalTester(tester);

    await _testBasicEval(evalTester);
    await _testAssignment(evalTester);

    await switchToScreen(tester, ScreenMetaData.memory);

    await _testRootIsAccessible(evalTester);
  });
}

Future<void> _testBasicEval(_EvalTester tester) async {
  await tester.testEval('21 + 34', '55');
}

Future<void> _testAssignment(_EvalTester tester) async {
  await tester.testEval('DateTime(2023)', 'DateTime');
  await tester.testEval(
    r'var x = $0',
    'Variable x is created ',
    exact: false,
  );
  await tester.testEval('x.toString()', "'${DateTime(2023).toString()}'");
}

Future<void> _testRootIsAccessible(_EvalTester tester) async {
  // TODO(polina-c): add content.
}

class _EvalTester {
  _EvalTester(this.tester);

  final WidgetTester tester;

  /// Tests if eval returns expected response by searching for response text.
  ///
  /// If [exact] is true, searches for exact match,
  /// otherwise for just containment.
  Future<void> testEval(
    String expression,
    String expectedResponse, {
    bool exact = true,
  }) async {
    await tester.tap(find.byType(AutoCompleteSearchField));
    await tester.pump(safePumpDuration);
    await tester.enterText(find.byType(AutoCompleteSearchField), expression);
    await tester.pump(safePumpDuration);
    await _pressEnter();
    await tester.pump(longPumpDuration);

    try {
      if (exact) {
        expect(
          find.widgetWithText(ConsolePane, expectedResponse),
          findsOneWidget,
        );
      } else {
        expect(
          find.textContaining(expectedResponse),
          findsOneWidget,
        );
      }
    } catch (e) {
      // In case of unexpected response take golden for troubleshooting.
      print('Unexpected response: $e');
      await expectLater(
        find.byType(ConsolePane),
        matchesGoldenFile('eval_and_browse_testEval.png'),
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
}
