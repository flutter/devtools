// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed parsed by test runner.
// test-argument:experimentsOn=true
// test-argument:appPath="test/test_infra/fixtures/memory_app"

import 'dart:ui' as ui;

import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_app/src/shared/console/widgets/evaluate.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_test/devtools_integration_test.dart';
import 'package:flutter/material.dart';
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

    final screenTitle = ScreenMetaData.memory.title;

    logStatus('switching to $screenTitle screen');
    await tester.tap(find.widgetWithText(Tab, screenTitle));
    // We use pump here instead of pumpAndSettle because pumpAndSettle will
    // never complete if there is an animation (e.g. a progress indicator).
    await tester.pump(safePumpDuration);

    await _testBasicEval(tester);
    await _testAssignment(tester);
    await _testRootIsAccessible(tester);
  });
}

Future<void> _testBasicEval(WidgetTester tester) async {
  await _enterExpression(tester, '21 + 34', '55');
}

Future<void> _testAssignment(WidgetTester tester) async {
  await _enterExpression(tester, 'DateTime(2023)', 'DateTime');
  await _enterExpression(tester, r'var x = $0', 'Variable x is created');
}

Future<void> _testRootIsAccessible(WidgetTester tester) async {}

Future<void> _enterExpression(
  WidgetTester tester,
  String expression,
  String expectedResponse,
) async {
  await tester.enterText(find.byType(ExpressionEvalField), expression);
  await simulateKeyDownEvent(LogicalKeyboardKey.enter);
  await tester.pump(safePumpDuration);
  expect(find.widgetWithText(ConsolePane, expectedResponse), findsOneWidget);
}

class _ConsoleActions {
  final WidgetTester tester;
}
