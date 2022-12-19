// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';

import 'test_infra/_run_test.dart';

// To run this test, run the following from `devtools_app/`:
// `dart run integration_test/run_test.dart`
//
// Arguments that may be passed to this command:
// --target=<path/to/test.dart> - this will run a single test at the path
//    provided.
// --test-app-uri=<some vm service uri> - this will connect DevTools to the app
//    you specify instead of spinning up a test app inside
//    [runFlutterIntegrationTest].
// --enable-experiments - this will run the DevTools integration tests with
//    DevTools experiments enabled (see feature_flags.dart)
// --headless - this will run the integration test on the 'web-server' device
//    instead of the 'chrome' device, meaning you will not be able to see the
//    integration test run in Chrome when running locally.

void main(List<String> args) async {
  final targetProvided =
      args.firstWhereOrNull((arg) => arg.startsWith(TestArgs.testTargetArg)) !=
          null;
  if (targetProvided) {
    // Run the single test at this path.
    final testRunnerArgs = TestArgs(args);
    await runFlutterIntegrationTest(testRunnerArgs);
  } else {
    // Ran all tests since a target test was not provided.
    const testSuffix = '_test.dart';

    // TODO(kenz): if we end up having several subdirectories under
    // `integration_test/test`, we could allow the directory to be modified with
    // an argument (e.g. --directory=integration_test/test/performance).
    final testDirectory = Directory('integration_test/test');
    final testFiles = testDirectory
        .listSync()
        .where((testFile) => testFile.path.endsWith(testSuffix));
    for (final testFile in testFiles) {
      final testTarget = testFile.path;
      final testRunnerArgs = TestArgs([
        ...args,
        '${TestArgs.testTargetArg}$testTarget',
      ]);
      await runFlutterIntegrationTest(testRunnerArgs);
    }
  }
}
