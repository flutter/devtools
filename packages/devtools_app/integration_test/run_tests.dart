// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_shared/devtools_test_utils.dart';

import 'test_infra/run/_in_file_args.dart';
import 'test_infra/run/_utils.dart';
import 'test_infra/run/run_test.dart';

// To run integration tests, run the following from `devtools_app/`:
// `dart run integration_test/run_tests.dart`
//
// To see a list of arguments that you can pass to this test script, please run
// the above command with the '-h' flag.

const _testDirectory = 'integration_test/test';
const _offlineIndicator = 'integration_test/test/offline';

/// The set of test that should be skipped for all devices.
///
/// This list should be empty most of the time, but may contain a broken test
/// while a fix being worked on.
///
/// Format: `'my_example_test.dart'`.
final List<String> _skipTests = <String>[
  // https://github.com/flutter/devtools/issues/6592
  'eval_and_browse_test.dart',
  // https://github.com/flutter/devtools/issues/7425
  'export_snapshot_test.dart',
];

void main(List<String> args) async {
  final testRunnerArgs = DevToolsAppTestRunnerArgs(
    args,
    verifyValidTarget: false,
  );

  await runOneOrManyTests<DevToolsAppTestRunnerArgs>(
    testDirectoryPath: _testDirectory,
    testRunnerArgs: testRunnerArgs,
    runTest: _runTest,
    newArgsGenerator: (args) => DevToolsAppTestRunnerArgs(args),
    testIsSupported: (testFile) =>
        testRunnerArgs.testAppDevice.supportsTest(testFile.path),
    debugLogging: debugTestScript,
  );
}

Future<void> _runTest(
  DevToolsAppTestRunnerArgs testRunnerArgs,
) async {
  final testTarget = testRunnerArgs.testTarget!;

  final shouldSkip = _skipTests.any((t) => testTarget.endsWith(t));
  if (shouldSkip) return;

  if (!testRunnerArgs.testAppDevice.supportsTest(testTarget)) {
    // Skip test, since it is not supported for device.
    return;
  }

  await runFlutterIntegrationTest(
    testRunnerArgs,
    TestFileArgs(testTarget, testAppDevice: testRunnerArgs.testAppDevice),
    offline: testTarget.startsWith(_offlineIndicator),
  );
}
