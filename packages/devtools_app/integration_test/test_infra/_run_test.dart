// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'io_utils.dart';
import 'test_app_driver.dart';

bool _debugTestScript = false;

Future<void> runFlutterIntegrationTest(
  List<String> args, {
  String testAppPath = 'test/test_infra/fixtures/flutter_app',
}) async {
  final testRunnerArgs = TestArgs(args);

  TestFlutterApp? testApp;
  late String testAppUri;

  final bool shouldCreateTestApp = testRunnerArgs.testAppUri == null;
  if (shouldCreateTestApp) {
    // Create the test app and start it.
    // TODO(kenz): support running Dart CLI test apps from here too.
    testApp = TestFlutterApp(appPath: testAppPath);
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
    enableExperiments: testRunnerArgs.enableExperiments,
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

class ChromeDriver with IOMixin {
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

class TestRunner with IOMixin {
  Future<void> run(
    String testTarget, {
    bool headless = false,
    bool enableExperiments = false,
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
        if (enableExperiments) '--dart-define=enable_experiments=true',
      ],
    );
    listenToProcessOutput(process);

    await process.exitCode;
    process.kill();
    _debugLog('flutter drive process has exited');
  }
}

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
    headless = args.contains(headlessArg);
  }

  static const testTargetArg = '--target=';
  static const testAppArg = '--test-app-uri=';
  static const enableExperimentsArg = '--enable-experiments';
  static const headlessArg = '--headless';

  late final String testTarget;
  late final String? testAppUri;
  late final bool enableExperiments;
  late final bool headless;
}
