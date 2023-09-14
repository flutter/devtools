// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'test_infra/run/_chrome_driver.dart';
import 'test_infra/run/_in_file_args.dart';
import 'test_infra/run/run_test.dart';

// To run integration tests, run the following from `devtools_app/`:
// `dart run integration_test/run_tests.dart`
//
// To see a list of arguments that you can pass to this test script, please run
// the above command with the '-h' flag.

const _testDirectory = 'integration_test/test';
const _testSuffix = '_test.dart';
const _offlineIndicator = 'integration_test/test/offline';

void main(List<String> args) async {
  final testRunnerArgs = TestRunnerArgs(args, verifyValidTarget: false);
  if (testRunnerArgs.help) {
    testRunnerArgs.printHelp();
    return;
  }

  final chromedriver = ChromeDriver();

  try {
    // Start chrome driver before running the flutter integration test.
    await chromedriver.start();

    if (testRunnerArgs.testTarget != null) {
      // TODO(kenz): add support for specifying a directory as the target instead
      // of a single file.
      await _runTest(testRunnerArgs);
    } else {
      // Run all tests since a target test was not provided.
      final testDirectory = Directory(_testDirectory);
      var testFiles = testDirectory
          .listSync(recursive: true)
          .where((testFile) => testFile.path.endsWith(_testSuffix))
          .toList();

      final shard = testRunnerArgs.shard;
      if (shard != null) {
        final shardSize = testFiles.length ~/ shard.totalShards;
        // Subtract 1 since the [shard.shardNumber] index is 1-based.
        final shardStart = (shard.shardNumber - 1) * shardSize;
        final shardEnd = shard.shardNumber == shard.totalShards
            ? null
            : shardStart + shardSize;
        testFiles = testFiles.sublist(shardStart, shardEnd);
      }

      for (final testFile in testFiles) {
        final testTarget = testFile.path;
        final newArgsWithTarget = TestRunnerArgs([
          ...args,
          '--${TestRunnerArgs.testTargetArg}=$testTarget',
        ]);
        await _runTest(newArgsWithTarget);
      }
    }
  } finally {
    await chromedriver.stop();
  }
}

Future<void> _runTest(
  TestRunnerArgs testRunnerArgs,
) async {
  final testTarget = testRunnerArgs.testTarget!;
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
