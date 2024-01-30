// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_test_utils.dart';

// To run integration tests, run the following from `devtools_extensions/`:
// `dart run integration_test/run_tests.dart`
//
// To see a list of arguments that you can pass to this test script, please run
// the above command with the '-h' flag.

const _testDirectory = 'integration_test/test';

bool debugTestScript = true;

void main(List<String> args) async {
  final testRunnerArgs = IntegrationTestRunnerArgs(
    args,
    verifyValidTarget: false,
  );

  await runOneOrManyTests(
    testDirectoryPath: _testDirectory,
    testRunnerArgs: testRunnerArgs,
    runTest: _runIntegrationTest,
    newArgsGenerator: (args) => IntegrationTestRunnerArgs(args),
    debugLogging: debugTestScript,
  );
}

Future<void> _runIntegrationTest(
  IntegrationTestRunnerArgs testRunnerArgs,
) async {
  final testRunner = IntegrationTestRunner();
  try {
    await testRunner.run(
      testRunnerArgs.testTarget!,
      testDriver: 'test_driver/integration_test.dart',
      headless: testRunnerArgs.headless,
      dartDefineArgs: ['use_simulated_environment=true'],
      debugLogging: debugTestScript,
    );
  } finally {
    await testRunner.cancelAllStreamSubscriptions();
  }
}
