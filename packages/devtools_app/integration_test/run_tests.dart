// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'test_infra/run/_in_file_args.dart';
import 'test_infra/run/run_test.dart';

// To run integration tests, run the following from `devtools_app/`:
// `dart run integration_test/run_tests.dart`
//
// Arguments that may be passed to this command:
// --target=<path/to/test.dart> - this will run a single test at the path
//    provided.
// --test-app-uri=<some vm service uri> - this will connect DevTools to the app
//    you specify instead of spinning up a test app inside
//    [runFlutterIntegrationTest].
// --update-goldens - this will update the current golden images with the
//   results from this test run
// --headless - this will run the integration test on the 'web-server' device
//    instead of the 'chrome' device, meaning you will not be able to see the
//    integration test run in Chrome when running locally.

const _testDirectory = 'integration_test/test';
const _testSuffix = '_test.dart';
const _offlineIndicator = 'integration_test/test/offline';

void main(List<String> testRunnerArgs) async {
  final testTargetProvided = testRunnerArgs
      .where((arg) => arg.startsWith(TestRunnerArgs.testTargetArg))
      .isNotEmpty;

  if (testTargetProvided) {
    final testFilePath = TestRunnerArgs(testRunnerArgs).testTarget!;

    // TODO(kenz): add support for specifying a directory as the target instead
    // of a single file.
    await _runTest(testRunnerArgs, testFilePath);
  } else {
    final testAppDevice =
        TestAppDevice.fromArgName(TestRunnerArgs(testRunnerArgs).testAppDevice);

    // Run all tests for the given test app device since a target test was not
    // provided.
    final testDirectory = Directory(_testDirectory);
    final testFiles = testDirectory.listSync(recursive: true).where(
          (testFile) =>
              testFile.path.endsWith(_testSuffix) &&
              testAppDevice!.supportsTest(testFile.path),
        );

    for (final testFile in testFiles) {
      final testTarget = testFile.path;
      await _runTest(
        [
          ...testRunnerArgs,
          '${TestRunnerArgs.testTargetArg}$testTarget',
        ],
        testTarget,
      );
    }
  }
}

Future<void> _runTest(
  List<String> testRunnerArgs,
  String testFilePath,
) async {
  await runFlutterIntegrationTest(
    TestRunnerArgs(testRunnerArgs),
    TestFileArgs(testFilePath),
    offline: testFilePath.startsWith(_offlineIndicator),
  );
}
