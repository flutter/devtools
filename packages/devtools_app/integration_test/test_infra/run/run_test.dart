// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:devtools_shared/devtools_test_utils.dart';

import '_in_file_args.dart';
import '_test_app_driver.dart';
import '_utils.dart';

/// Runs one test.
///
/// Do not use this method directly, but instead use the run_tests.dart
/// which performs essential set up steps.
Future<void> runFlutterIntegrationTest(
  DevToolsAppTestRunnerArgs testRunnerArgs,
  TestFileArgs testFileArgs, {
  required bool offline,
}) async {
  IntegrationTestApp? testApp;
  late String testAppUri;

  if (!offline) {
    if (testRunnerArgs.testAppUri == null) {
      debugLog('Starting a test application');
      // Create the test app and start it.
      try {
        if (testRunnerArgs.testAppDevice == TestAppDevice.cli) {
          debugLog(
            'Creating a TestDartCliApp with path ${testFileArgs.appPath}',
          );
          testApp = TestDartCliApp(appPath: testFileArgs.appPath);
        } else {
          debugLog(
            'Creating a TestFlutterApp with path ${testFileArgs.appPath} and '
            'device ${testRunnerArgs.testAppDevice}',
          );
          testApp = TestFlutterApp(
            appPath: testFileArgs.appPath,
            appDevice: testRunnerArgs.testAppDevice,
          );
        }
        await testApp.start();
      } catch (e) {
        // ignore: avoid-throw-in-catch-block, by design
        throw Exception('Error starting test app: $e');
      }
      testAppUri = testApp.vmServiceUri.toString();
    } else {
      testAppUri = testRunnerArgs.testAppUri!;
    }
  }

  // Run the flutter integration test.
  final testRunner = IntegrationTestRunner();
  try {
    final testArgs = <String, Object>{
      if (!offline) 'service_uri': testAppUri,
    };
    await testRunner.run(
      testRunnerArgs.testTarget!,
      testDriver: 'test_driver/integration_test.dart',
      headless: testRunnerArgs.headless,
      dartDefineArgs: [
        'test_args=${jsonEncode(testArgs)}',
        if (testFileArgs.experimentsOn) 'enable_experiments=true',
        if (testRunnerArgs.updateGoldens) 'update_goldens=true',
      ],
      debugLogging: debugTestScript,
    );
  } finally {
    if (testApp != null) {
      debugLog('killing the test app');
      await testApp.stop();
    }

    debugLog('cancelling stream subscriptions');
    await testRunner.cancelAllStreamSubscriptions();
  }
}

class DevToolsAppTestRunnerArgs extends IntegrationTestRunnerArgs {
  DevToolsAppTestRunnerArgs(super.args, {super.verifyValidTarget = true})
      : super(addExtraArgs: _addExtraArgs) {
    testAppDevice = TestAppDevice.fromArgName(
      argResults[_testAppDeviceArg] ?? TestAppDevice.flutterTester.argName,
    )!;
  }

  /// The type of device for the test app to run on.
  late final TestAppDevice testAppDevice;

  /// The Vm Service URI for the test app to connect devtools to.
  ///
  /// This value will only be used for tests with live connection.
  String? get testAppUri => argResults[_testAppUriArg];

  /// Whether golden images should be updated with the result of this test run.
  bool get updateGoldens => argResults[_updateGoldensArg];

  static const _testAppUriArg = 'test-app-uri';
  static const _testAppDeviceArg = 'test-app-device';
  static const _updateGoldensArg = 'update-goldens';

  /// Adds additional argument handlers to [argParser] that are specific to
  /// integration tests in package:devtools_app.
  static void _addExtraArgs(ArgParser argParser) {
    argParser
      ..addOption(
        _testAppUriArg,
        help: 'The vm service connection to use for the app that DevTools will '
            'connect to during the integration test. If left empty, a sample app '
            'will be spun up as part of the integration test process.',
      )
      ..addOption(
        _testAppDeviceArg,
        help:
            'The device to use for the test app that DevTools will connect to.',
      )
      ..addFlag(
        _updateGoldensArg,
        negatable: false,
        help: 'Updates the golden images with the results of this test run.',
      );
  }
}
