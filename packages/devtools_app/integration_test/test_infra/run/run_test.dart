// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';

import '_in_file_args.dart';
import '_io_utils.dart';
import '_test_app_driver.dart';

bool _debugTestScript = false;

/// Runs one test.
///
/// Do not use this method directly, but instead use the run_tests.dart
/// which performs essential set up steps.
Future<void> runFlutterIntegrationTest(
  TestRunnerArgs testRunnerArgs,
  TestFileArgs testFileArgs, {
  required bool offline,
}) async {
  TestFlutterApp? testApp;
  late String testAppUri;

  if (!offline) {
    if (testRunnerArgs.testAppUri == null) {
      // Create the test app and start it.
      try {
        testApp = TestFlutterApp(
          appPath: testFileArgs.appPath,
          appDevice: testRunnerArgs.testAppDevice,
        );
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

  // TODO(kenz): do we need to start chromedriver in headless mode?
  // Start chrome driver before running the flutter integration test.
  final chromedriver = ChromeDriver();
  try {
    await chromedriver.start();
  } catch (e) {
    // ignore: avoid-throw-in-catch-block, by design
    throw Exception('Error starting chromedriver: $e');
  }

  // Run the flutter integration test.
  final testRunner = TestRunner();
  Exception? exception;
  try {
    await testRunner.run(
      testRunnerArgs.testTarget!,
      enableExperiments: testFileArgs.experimentsOn,
      updateGoldens: testRunnerArgs.updateGoldens,
      headless: testRunnerArgs.headless,
      testAppArguments: {
        if (!offline) 'service_uri': testAppUri,
      },
    );
  } on Exception catch (e) {
    exception = e;
  } finally {
    if (testApp != null) {
      _debugLog('killing the test app');
      await testApp.stop();
    }

    _debugLog('cancelling stream subscriptions');
    await testRunner.cancelAllStreamSubscriptions();
    await chromedriver.cancelAllStreamSubscriptions();

    _debugLog('killing the chromedriver process');
    chromedriver.kill();
  }

  if (exception != null) {
    throw exception;
  }
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
    listenToProcessOutput(_process, printTag: 'ChromeDriver');
  }

  void kill() {
    _process.kill();
  }
}

class TestRunner with IOMixin {
  static const _beginExceptionMarker = 'EXCEPTION CAUGHT';
  static const _endExceptionMarker = '═════════════════════════';
  static const _errorMarker = ': Error: ';
  static const _unhandledExceptionMarker = 'Unhandled exception:';
  static const _allTestsPassed = 'All tests passed!';
  static const _maxRetriesOnTimeout = 1;

  Future<void> run(
    String testTarget, {
    bool headless = false,
    bool enableExperiments = false,
    bool updateGoldens = false,
    Map<String, Object> testAppArguments = const <String, Object>{},
  }) async {
    Future<void> runTest({required int attemptNumber}) async {
      _debugLog('starting the flutter drive process');
      final process = await Process.start(
        'flutter',
        [
          'drive',
          // Debug outputs from the test will not show up in profile mode. Since
          // we rely on debug outputs for detecting errors and exceptions from the
          // test, we cannot run this these tests in profile mode until this issue
          // is resolved.  See https://github.com/flutter/flutter/issues/69070.
          // '--profile',
          '--driver=test_driver/integration_test.dart',
          '--target=$testTarget',
          '-d',
          headless ? 'web-server' : 'chrome',
          if (testAppArguments.isNotEmpty)
            '--dart-define=test_args=${jsonEncode(testAppArguments)}',
          if (enableExperiments) '--dart-define=enable_experiments=true',
          if (updateGoldens) '--dart-define=update_goldens=true',
        ],
      );

      bool stdOutWriteInProgress = false;
      bool stdErrWriteInProgress = false;
      final exceptionBuffer = StringBuffer();

      var testsPassed = false;
      listenToProcessOutput(
        process,
        printTag: 'FlutterDriveProcess',
        onStdout: (line) {
          if (line.endsWith(_allTestsPassed)) {
            testsPassed = true;
          }

          if (line.startsWith(_TestResult.testResultPrefix)) {
            final testResultJson = line.substring(line.indexOf('{'));
            final testResultMap =
                jsonDecode(testResultJson) as Map<String, Object?>;
            final result = _TestResult.parse(testResultMap);
            if (!result.result) {
              exceptionBuffer
                ..writeln('$result')
                ..writeln();
            }
          }

          if (line.contains(_beginExceptionMarker)) {
            stdOutWriteInProgress = true;
          }
          if (stdOutWriteInProgress) {
            exceptionBuffer.writeln(line);
            // Marks the end of the exception caught by flutter.
            if (line.contains(_endExceptionMarker) &&
                !line.contains(_beginExceptionMarker)) {
              stdOutWriteInProgress = false;
              exceptionBuffer.writeln();
            }
          }
        },
        onStderr: (line) {
          if (line.contains(_errorMarker) ||
              line.contains(_unhandledExceptionMarker)) {
            stdErrWriteInProgress = true;
          }
          if (stdErrWriteInProgress) {
            exceptionBuffer.writeln(line);
          }
        },
      );

      bool testTimedOut = false;
      final timeout = Future.delayed(const Duration(minutes: 8)).then((_) {
        testTimedOut = true;
      });

      await Future.any([
        process.exitCode,
        timeout,
      ]);

      _debugLog('attempting to kill the flutter drive process');
      process.kill();
      _debugLog('flutter drive process has exited');

      // Ignore exception handling and retries if the tests passed. This is to
      // avoid bugs with the test runner where the test can fail after the test
      // has passed. See https://github.com/flutter/flutter/issues/129041.
      if (!testsPassed) {
        if (testTimedOut) {
          if (attemptNumber >= _maxRetriesOnTimeout) {
            throw Exception(
              'Integration test timed out on try #$attemptNumber: $testTarget',
            );
          } else {
            _debugLog(
              'Integration test timed out on try #$attemptNumber. Retrying '
              '$testTarget now.',
            );
            await runTest(attemptNumber: ++attemptNumber);
          }
        }

        if (exceptionBuffer.isNotEmpty) {
          throw Exception(exceptionBuffer.toString());
        }
      }
    }

    await runTest(attemptNumber: 0);
  }
}

class _TestResult {
  _TestResult._(this.result, this.methodName, this.details);

  factory _TestResult.parse(Map<String, Object?> json) {
    final result = json[resultKey] == 'true';
    final failureDetails =
        (json[failureDetailsKey] as List<Object?>).cast<String>().firstOrNull ??
            '{}';
    final failureDetailsMap =
        jsonDecode(failureDetails) as Map<String, Object?>;
    final methodName = failureDetailsMap[methodNameKey] as String?;
    final details = failureDetailsMap[detailsKey] as String?;
    return _TestResult._(result, methodName, details);
  }

  static const testResultPrefix = 'result {"result":';
  static const resultKey = 'result';
  static const failureDetailsKey = 'failureDetails';
  static const methodNameKey = 'methodName';
  static const detailsKey = 'details';

  final bool result;
  final String? methodName;
  final String? details;

  @override
  String toString() {
    if (result) {
      return 'Test passed';
    }
    return 'Test \'$methodName\' failed: $details.';
  }
}

void _debugLog(String log) {
  if (_debugTestScript) {
    print(log);
  }
}

class TestRunnerArgs {
  TestRunnerArgs(List<String> args, {bool verifyValidTarget = true}) {
    final argParser = _buildArgParser();
    _argResults = argParser.parse(args);

    if (verifyValidTarget) {
      final target = _argResults[testTargetArg];
      assert(
        target != null,
        'Please specify a test target (e.g. '
        '--$testTargetArg=path/to/test.dart',
      );
    }

    testAppDevice = TestAppDevice.fromArgName(
      _argResults[_testAppDeviceArg] ?? TestAppDevice.flutterTester.argName,
    )!;
  }

  late final ArgResults _argResults;

  /// The path to the test target.
  String? get testTarget => _argResults[testTargetArg];

  /// The type of device for the test app to run on.
  late final TestAppDevice testAppDevice;

  /// The Vm Service URI for the test app to connect devtools to.
  ///
  /// This value will only be used for tests with live connection.
  String? get testAppUri => _argResults[_testAppUriArg];

  /// Whether golden images should be updated with the result of this test run.
  bool get updateGoldens => _argResults[_updateGoldensArg];

  /// Whether this integration test should be run on the 'web-server' device
  /// instead of 'chrome'.
  bool get headless => _argResults[_headlessArg];

  static const _helpArg = 'help';
  static const testTargetArg = 'target';
  static const _testAppUriArg = 'test-app-uri';
  static const _testAppDeviceArg = 'test-app-device';
  static const _updateGoldensArg = 'update-goldens';
  static const _headlessArg = 'headless';

  /// Builds an arg parser for DevTools integration tests.
  static ArgParser _buildArgParser() {
    final argParser = ArgParser()
      ..addFlag(
        _helpArg,
        abbr: 'h',
        help: 'Prints help output.',
      )
      ..addOption(
        testTargetArg,
        abbr: 't',
        help:
            'The integration test target (e.g. path/to/test.dart). If left empty,'
            ' all integration tests will be run.',
      )
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
      )
      ..addFlag(
        _headlessArg,
        negatable: false,
        help:
            'Runs the integration test on the \'web-server\' device instead of '
            'the \'chrome\' device. For headless test runs, you will not be '
            'able to see the integration test run visually in a Chrome browser.',
      );
    return argParser;
  }
}

enum TestAppDevice {
  flutterTester('flutter-tester'),
  chrome('chrome');

  // TODO(https://github.com/flutter/devtools/issues/5953): support a Dart CLI
  // test device.

  const TestAppDevice(this.argName);

  final String argName;

  /// A mapping of test app device to the unsupported tests for that device.
  static final _unsupportedTestsForDevice = <TestAppDevice, List<String>>{
    TestAppDevice.flutterTester: [],
    TestAppDevice.chrome: [
      // TODO(https://github.com/flutter/devtools/issues/5874): Remove once supported on web.
      'eval_and_browse_test.dart',
      'perfetto_test.dart',
      'performance_screen_event_recording_test.dart',
      'service_connection_test.dart',
    ],
  };

  static final _argNameToDeviceMap =
      TestAppDevice.values.fold(<String, TestAppDevice>{}, (map, device) {
    map[device.argName] = device;
    return map;
  });

  static TestAppDevice? fromArgName(String argName) {
    return _argNameToDeviceMap[argName];
  }

  bool supportsTest(String testPath) {
    final unsupportedTests = _unsupportedTestsForDevice[this] ?? [];
    return unsupportedTests
        .none((unsupportedTestPath) => testPath.endsWith(unsupportedTestPath));
  }
}
