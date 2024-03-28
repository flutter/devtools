// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed by test runner.
// test-argument:appPath="test/test_infra/fixtures/memory_app"

import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'eval_utils.dart';
import 'memory_screen_helpers.dart';

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

    final evalTester = EvalTester(tester);
    await prepareMemoryUI(tester, makeConsoleWider: true);

    logStatus('test basic evaluation');
    await testBasicEval(evalTester);

    logStatus('test variable assignment');
    await testAssignment(evalTester);

    logStatus('test dump one instance to console');
    await _profileOneInstance(evalTester);

    logStatus('test dump all instances to console');
    await _profileAllInstances(evalTester);

    logStatus('test take a snapshot');
    await evalTester.takeSnapshot();

    logStatus('test inbound references are listed on console instance');
    await _inboundReferencesAreListed(evalTester);
  });
}

Future<void> _profileOneInstance(EvalTester tester) async {
  await tester.openContextMenuForClass('MyHomePage');
  await tester.tapAndPump(
    find.textContaining('one instance'),
    duration: longPumpDuration,
  );
  expect(find.text('MyHomePage'), findsNWidgets(2));
}

Future<void> _profileAllInstances(EvalTester tester) async {
  await tester.openContextMenuForClass('_MyHomePageState');
  await tester.tapAndPump(find.textContaining('all class instances'));
  await tester.tapAndPump(
    find.text('Direct instances'),
    duration: longPumpDuration,
  );

  expect(find.text('List (1 item)'), findsOneWidget);
}

Future<void> _inboundReferencesAreListed(EvalTester tester) async {
  await tester.openContextMenuForClass('MyApp');

  await tester.tapAndPump(find.textContaining('one instance'));
  await tester.tapAndPump(find.text('Any'), duration: longPumpDuration);

  Finder? next = await tester.tapAndPump(
    find.textContaining('MyApp, retained size '),
    next: find.text('references'),
  );
  next = await tester.tapAndPump(
    next!,
    next: find.textContaining('static ('),
  );
  next = await tester.tapAndPump(
    next!,
    description: 'text containing "static ("',
    next: find.text('inbound'),
  );
  next = await tester.tapAndPump(
    next!,
    next: find.text('View'),
  );
}
