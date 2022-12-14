// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'io_utils.dart';
import 'test_app_driver.dart';

const testTargetArg = '--target=';
const testAppArg = '--test-app-uri=';

Future<void> runTest(List<String> args) async {
  // TODO(kenz): consider using ArgParser from package:args to clean this up.
  final argWithTestTarget =
      args.firstWhereOrNull((arg) => arg.startsWith(testTargetArg));
  if (argWithTestTarget == null) {
    throw Exception(
      'Please specify a test target (e.g. --target=path/to/test.dart',
    );
  }
  final testTarget = argWithTestTarget.substring(testTargetArg.length);

  TestFlutterApp? testApp;
  String? testAppUri;

  final argWithTestAppUri =
      args.firstWhereOrNull((arg) => arg.startsWith(testAppArg));
  final createTestApp = argWithTestAppUri == null;

  if (createTestApp) {
    testApp = TestFlutterApp();
    await testApp.start();
    testAppUri = testApp.vmServiceUri.toString();
  } else {
    testAppUri = argWithTestAppUri.substring(testAppArg.length);
  }

  final chromedriver = ChromeDriver();
  await chromedriver.start();

  final headless = args.contains('--headless');
  final enableExperiments = args.contains('--enable-experiments');
  final testArgs = {
    'service_uri': testAppUri,
  };
  final testRunner = TestRunner();
  await testRunner.run(
    testTarget,
    enableExperiements: enableExperiments,
    headless: headless,
    args: testArgs,
  );

  if (createTestApp) {
    _debugLog('killing the test app');
    await testApp?.killGracefully();
  }

  _debugLog('cancelling stream subscriptions');
  await testRunner.cancelAllStreamSubscriptions();
  await chromedriver.cancelAllStreamSubscriptions();
  _debugLog('end of main');
}

class ChromeDriver with IoMixin {
  // TODO(kenz): add error messaging if the chromedriver executable is not
  // found. We can also consider using web installers directly in this script:
  // https://github.com/flutter/flutter/wiki/Running-Flutter-Driver-tests-with-Web#web-installers-repo.
  Future<void> start() async {
    _debugLog('starting the chromedriver process');
    final process = await Process.start(
      'chromedriver',
      [
        '--port=4444',
      ],
    );
    listenToProcessOutput(process);
  }
}

class TestRunner with IoMixin {
  Future<void> run(
    String testTarget, {
    bool headless = false,
    bool enableExperiements = false,
    Map<String, Object> args = const <String, Object>{},
  }) async {
    _debugLog('starting the flutter drive process');
    final process = await Process.start(
      'flutter',
      [
        'drive',
        '--driver=test_driver/integration_test.dart',
        '--target=$testTarget',
        '-d',
        headless ? 'web-server' : 'chrome',
        if (args.isNotEmpty) '--dart-define=test_args=${jsonEncode(args)}',
        if (enableExperiements) '--dart-define=enable_experiments=true',
      ],
    );
    listenToProcessOutput(process);

    await process.exitCode;
    _debugLog('flutter drive process has exited');
  }
}

bool _debugTestScript = true;
void _debugLog(String log) {
  if (_debugTestScript) {
    print(log);
  }
}
