// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:devtools_shared/devtools_test_utils.dart';

import '_in_file_args.dart';
import '_test_app_driver.dart';
import '_utils.dart';

/// The identifier for the stdout line that contains the DevTools server
/// address when starting from the `dart devtools` command.
const _devToolsServerAddressLine = 'Serving DevTools at ';

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

  String? devToolsServerAddress;
  Process? devToolsServerProcess;
  if (testFileArgs.startDevToolsServer) {
    // TODO(https://github.com/flutter/devtools/issues/9196): support starting
    // DTD and passing the URI to DevTools server. Workspace roots should be set
    // on the DTD instance based on the connected test app.
    devToolsServerProcess = await startDevToolsServer();
    devToolsServerAddress = await listenForDevToolsAddress(
      devToolsServerProcess,
    );
  }

  if (!offline) {
    if (testRunnerArgs.testAppUri == null) {
      // Create the test app and start it.
      try {
        if (testRunnerArgs.testAppDevice == TestAppDevice.cli) {
          debugLog(
            'creating a TestDartCliApp with path ${testFileArgs.appPath}',
          );
          testApp = TestDartCliApp(appPath: testFileArgs.appPath);
        } else {
          debugLog(
            'creating a TestFlutterApp with path ${testFileArgs.appPath} and '
            'device ${testRunnerArgs.testAppDevice}',
          );
          testApp = TestFlutterApp(
            appPath: testFileArgs.appPath,
            appDevice: testRunnerArgs.testAppDevice,
          );
        }
        debugLog('starting the test app');
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
    final testArgs = <String, Object?>{if (!offline) 'service_uri': testAppUri};
    final testTarget = testRunnerArgs.testTarget!;
    debugLog('starting test run for $testTarget');
    await testRunner.run(
      testTarget,
      testDriver: 'test_driver/integration_test.dart',
      headless: testRunnerArgs.headless,
      dartDefineArgs: [
        'test_args=${jsonEncode(testArgs)}',
        if (testFileArgs.experimentsOn) 'enable_experiments=true',
        if (testRunnerArgs.updateGoldens) 'update_goldens=true',
        if (devToolsServerAddress != null)
          // Add the trailing slash because this is what DevTools app expects.
          'debug_devtools_server=$devToolsServerAddress/',
      ],
      debugLogging: debugTestScript,
    );
  } finally {
    if (testApp != null) {
      debugLog('killing the test app');
      await testApp.stop();
    }

    if (devToolsServerProcess != null) {
      debugLog('killing the DevTools server');
      devToolsServerProcess.kill();
    }

    debugLog('cancelling stream subscriptions');
    await testRunner.cancelAllStreamSubscriptions();
  }
}

class DevToolsAppTestRunnerArgs extends IntegrationTestRunnerArgs {
  DevToolsAppTestRunnerArgs(super.args, {super.verifyValidTarget = true})
    : super(addExtraArgs: _addExtraArgs) {
    testAppDevice = TestAppDevice.fromArgName(
      argResults.option(_testAppDeviceArg) ??
          TestAppDevice.flutterTester.argName,
    )!;
  }

  /// The type of device for the test app to run on.
  late final TestAppDevice testAppDevice;

  /// The Vm Service URI for the test app to connect devtools to.
  ///
  /// This value will only be used for tests with live connection.
  String? get testAppUri => argResults.option(_testAppUriArg);

  /// Whether golden images should be updated with the result of this test run.
  bool get updateGoldens => argResults.flag(_updateGoldensArg);

  static const _testAppUriArg = 'test-app-uri';
  static const _testAppDeviceArg = 'test-app-device';
  static const _updateGoldensArg = 'update-goldens';

  /// Adds additional argument handlers to [argParser] that are specific to
  /// integration tests in package:devtools_app.
  static void _addExtraArgs(ArgParser argParser) {
    argParser
      ..addOption(
        _testAppUriArg,
        help:
            'The vm service connection to use for the app that DevTools will '
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

/// Starts the DevTools server.
///
/// Note: This will use the DevTools server that is shipped with the Dart SDK.
///
/// TODO(https://github.com/flutter/devtools/issues/9197): launch the
/// DevTools server from source so that end to end changes (server + app) can
/// be tested.
Future<Process> startDevToolsServer() async {
  final devToolsServerProcess = await Process.start('dart', [
    'devtools',
    // Do not launch DevTools app in the browser. This DevTools server
    // instance will be used to connect to the DevTools app that is run from
    // Flutter driver from the integration test runner.
    '--no-launch-browser',
    // Disable CORS restrictions so that we can connect to the server from
    // DevTools app that is served on a different origin.
    '--disable-cors',
  ]);
  return devToolsServerProcess;
}

/// Listens on the [devToolsServerProcess] stdout for the DevTool's address and
/// returns it.
Future<String> listenForDevToolsAddress(
  Process devToolsServerProcess, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final devToolsAddressCompleter = Completer<String>();

  final sub = devToolsServerProcess.stdout.transform(utf8.decoder).listen((
    line,
  ) {
    if (line.startsWith(_devToolsServerAddressLine)) {
      // This will pull the server address from a String like:
      // "Serving DevTools at http://127.0.0.1:9104.".
      final regexp = RegExp(r'http:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+');
      final match = regexp.firstMatch(line);
      if (match != null) {
        final devToolsServerAddress = match.group(0);
        devToolsAddressCompleter.complete(devToolsServerAddress);
      }
    }
  });

  await devToolsAddressCompleter.future.timeout(
    timeout,
    onTimeout: () async {
      await sub.cancel();
      devToolsServerProcess.kill();
      throw Exception('Timed out waiting for DevTools server to start.');
    },
  );
  await sub.cancel();

  return devToolsAddressCompleter.future;
}
