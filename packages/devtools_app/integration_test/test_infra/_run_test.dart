// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'io_utils.dart';
import 'test_app_driver.dart';

Future<void> runTest(List<String> args) async {
  final testRunnerArgs = TestArgs(args);

  TestFlutterApp? testApp;
  late String testAppUri;

  final bool shouldCreateTestApp = testRunnerArgs.testAppUri == null;
  if (shouldCreateTestApp) {
    // Create the test app and start it.
    testApp = TestFlutterApp();
    await testApp.start();
    testAppUri = testApp.vmServiceUri.toString();
  } else {
    testAppUri = testRunnerArgs.testAppUri!;
  }

  // TODO(kenz): do we need to start chromedriver in headless mode?
  // Start chrome driver before running the flutter integration test.
  final chromedriver = ChromeDriver();
  await chromedriver.start();

  // Run the flutter integration test.
  final testRunner = TestRunner();
  await testRunner.run(
    testRunnerArgs.testTarget,
    enableExperiements: testRunnerArgs.enableExperiments,
    updateGoldens: testRunnerArgs.updateGoldens,
    headless: testRunnerArgs.headless,
    testAppArguments: {
      'service_uri': testAppUri,
    },
  );

  if (shouldCreateTestApp) {
    _debugLog('killing the test app');
    await testApp?.killGracefully();
  }

  _debugLog('cancelling stream subscriptions');
  await testRunner.cancelAllStreamSubscriptions();
  await chromedriver.cancelAllStreamSubscriptions();

  _debugLog('killing the chromedriver process');
  chromedriver.kill();
}

class ChromeDriver with IoMixin {
  late final Process _process;

  // TODO(kenz): add error messaging if the chromedriver executable is not
  // found. We can also consider using web installers directly in this script:
  // https://github.com/flutter/flutter/wiki/Running-Flutter-Driver-tests-with-Web#web-installers-repo.
  Future<void> start() async {
    _debugLog('starting the chromedriver process');
    _process = await Process.start(
      'chromedriver',
      [
        '--port=4444',
      ],
    );
    listenToProcessOutput(_process);
  }

  void kill() {
    _process.kill();
  }
}

class TestRunner with IoMixin {
  Future<void> run(
    String testTarget, {
    bool headless = false,
    bool enableExperiements = false,
    bool updateGoldens = false,
    Map<String, Object> testAppArguments = const <String, Object>{},
  }) async {
    _debugLog('starting the flutter drive process');
    final process = await Process.start(
      'flutter',
      [
        'drive',
        '--profile',
        '--driver=test_driver/integration_test.dart',
        '--target=$testTarget',
        '-d',
        headless ? 'web-server' : 'chrome',
        if (testAppArguments.isNotEmpty)
          '--dart-define=test_args=${jsonEncode(testAppArguments)}',
        if (enableExperiements) '--dart-define=enable_experiments=true',
        if (updateGoldens) '--dart-define=update_goldens=true',
      ],
    );
    listenToProcessOutput(process);

    await process.exitCode;
    process.kill();
    _debugLog('flutter drive process has exited');
  }
}

bool _debugTestScript = true;
void _debugLog(String log) {
  if (_debugTestScript) {
    print(log);
  }
}

class TestArgs {
  TestArgs(List<String> args) {
    final argWithTestTarget =
        args.firstWhereOrNull((arg) => arg.startsWith(testTargetArg));
    final target = argWithTestTarget?.substring(testTargetArg.length);
    assert(
      target != null,
      'Please specify a test target (e.g. --target=path/to/test.dart',
    );
    testTarget = target!;

    final argWithTestAppUri =
        args.firstWhereOrNull((arg) => arg.startsWith(testAppArg));
    testAppUri = argWithTestAppUri?.substring(testAppArg.length);

    enableExperiments = args.contains(enableExperimentsArg);
    updateGoldens = args.contains(updateGoldensArg);
    headless = args.contains(headlessArg);
  }

  static const testTargetArg = '--target=';
  static const testAppArg = '--test-app-uri=';
  static const enableExperimentsArg = '--enable-experiments';
  static const updateGoldensArg = '--update-goldens';
  static const headlessArg = '--headless';

  late final String testTarget;
  late final String? testAppUri;
  late final bool enableExperiments;
  late final bool updateGoldens;
  late final bool headless;
}
