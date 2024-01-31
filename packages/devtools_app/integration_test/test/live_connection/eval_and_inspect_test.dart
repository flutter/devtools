// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed by test runner.
// test-argument:appPath="test/test_infra/fixtures/memory_app"
// test-argument:experimentsOn=true

// ignore_for_file: avoid_print

import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'eval_utils.dart';

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

    final evalTester = EvalTester(tester);
    await evalTester.prepareInspectorUI();

    logStatus('testing basic evaluation');
    await testBasicEval(evalTester);

    logStatus('testing variable assignment');
    await testAssignment(evalTester);

    logStatus('testing eval on widget tree node');
    await _testEvalOnWidgetTreeNode(evalTester);
  });
}

Future<void> _testEvalOnWidgetTreeNode(EvalTester tester) async {
  await tester.selectWidgetTreeNode(find.richText('FloatingActionButton'));
  await tester.testEval(
    r'var button = $0',
    find.textContaining('Variable button is created '),
  );
}
