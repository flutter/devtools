// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';

import 'test_infra/run/run_test.dart';

// To run this test, run the following from `devtools_app/`:
// `dart run integration_test/run_test.dart`
//
// Arguments that may be passed to this command:
// --target=<path/to/test.dart> - this will run a single test at the path
//    provided.
// --test-app-uri=<some vm service uri> - this will connect DevTools to the app
//    you specify instead of spinning up a test app inside
//    [runFlutterIntegrationTest].
// --offline - indicates that we do not need to start a test app to run this
//    test. This will take precedence if both --offline and --test-app-uri are
//    present.
// --enable-experiments - this will run the DevTools integration tests with
//    DevTools experiments enabled (see feature_flags.dart)
// --update-goldens - this will update the current golden images with the
//   results from this test run
// --headless - this will run the integration test on the 'web-server' device
//    instead of the 'chrome' device, meaning you will not be able to see the
//    integration test run in Chrome when running locally.

const _testDirectory = 'integration_test/test';
const _testSuffix = '_test.dart';
const _offlineIndicator = 'integration_test/test/offline';
const _experimentalIndicator = '/experimental/';

void main(List<String> args) async {
  final modifiableArgs = List.of(args);

  final testTarget = modifiableArgs
      .firstWhereOrNull((arg) => arg.startsWith(TestArgs.testTargetArg));
  if (testTarget != null) {
    // Run the single test at this path.
    _maybeAddOfflineArgument(modifiableArgs, testTarget);
    _maybeAddExperimentsArgument(modifiableArgs, testTarget);
    final testRunnerArgs = TestArgs(modifiableArgs);

    // TODO(kenz): add support for specifying a directory as the target instead
    // of a single file.
    await runFlutterIntegrationTest(testRunnerArgs);
  } else {
    // Run all tests since a target test was not provided.
    final testDirectory = Directory(_testDirectory);
    final testFiles = testDirectory
        .listSync(recursive: true)
        .where((testFile) => testFile.path.endsWith(_testSuffix));

    for (final testFile in testFiles) {
      final testTarget = testFile.path;
      _maybeAddOfflineArgument(modifiableArgs, testTarget);
      _maybeAddExperimentsArgument(modifiableArgs, testTarget);
      final testRunnerArgs = TestArgs([
        ...modifiableArgs,
        '${TestArgs.testTargetArg}$testTarget',
      ]);
      await runFlutterIntegrationTest(testRunnerArgs);
    }
  }
}

void _maybeAddOfflineArgument(List<String> args, String testTarget) {
  if (testTarget.startsWith(_offlineIndicator)) {
    args.add(TestArgs.offlineArg);
  }
}

void _maybeAddExperimentsArgument(List<String> args, String testTarget) {
  if (testTarget.contains(_experimentalIndicator)) {
    args.add(TestArgs.enableExperimentsArg);
  }
}
