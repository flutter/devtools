// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'io_utils.dart';
import 'test_app_driver.dart';

bool _debugTestScript = false;

Future<void> runFlutterIntegrationTest(
  TestArgs testRunnerArgs, {
  String testAppPath = 'test/test_infra/fixtures/flutter_app',
}) async {
  TestFlutterApp? testApp;
  late String testAppUri;

  if (!testRunnerArgs.offline) {
    if (testRunnerArgs.testAppUri == null) {
      // Create the test app and start it.
      // TODO(kenz): support running Dart CLI test apps from here too.
      try {
        testApp = TestFlutterApp(appPath: testAppPath);
        await testApp.start();
      } catch (e) {
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
    throw Exception('Error starting chromedriver: $e');
  }

  // Run the flutter integration test.
  final testRunner = TestRunner();
  Exception? exception;
  try {
    await testRunner.run(
      testRunnerArgs.testTarget,
      enableExperiments: testRunnerArgs.enableExperiments,
      updateGoldens: testRunnerArgs.updateGoldens,
      headless: testRunnerArgs.headless,
      testAppArguments: {
        if (!testRunnerArgs.offline) 'service_uri': testAppUri,
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
    listenToProcessOutput(_process);
  }

  void kill() {
    _process.kill();
  }
}

class TestRunner with IOMixin {
  static const _beginExceptionMarker = '| EXCEPTION CAUGHT';
  static const _endExceptionMarker = '===========================';
  static const _errorMarker = ': Error: ';
  static const _unhandledExceptionMarker = 'Unhandled exception:';
  static const _retriesOnTimeout = 1;

  Future<void> run(
    String testTarget, {
    bool headless = false,
    bool enableExperiments = false,
    bool updateGoldens = false,
    Map<String, Object> testAppArguments = const <String, Object>{},
  }) async {
    Future<void> _run({required int attemptNumber}) async {
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

      listenToProcessOutput(
        process,
        onStdout: (line) {
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
      final timeout = Future.delayed(const Duration(minutes: 6)).then((_) {
        testTimedOut = true;
      });

      await Future.any([
        process.exitCode,
        timeout,
      ]);

      process.kill();
      _debugLog('flutter drive process has exited');

      if (testTimedOut) {
        if (attemptNumber < _retriesOnTimeout) {
          throw Exception(
            'Integration test timed out on try #$attemptNumber: $testTarget',
          );
        } else {
          _debugLog(
            'Integration test timed out on try #$attemptNumber. Retrying '
            '$testTarget now.',
          );
          await _run(attemptNumber: ++attemptNumber);
        }
      }

      if (exceptionBuffer.isNotEmpty) {
        throw Exception(exceptionBuffer.toString());
      }
    }

    await _run(attemptNumber: 0);
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

// TODO(https://github.com/flutter/devtools/issues/4970): use package:args to
// parse these arguments.
class TestArgs {
  TestArgs(List<String> args) {
    final argWithTestTarget =
        args.firstWhereOrNull((arg) => arg.startsWith(testTargetArg));
    final target = argWithTestTarget?.substring(testTargetArg.length);
    assert(
      target != null,
      'Please specify a test target (e.g. ${testTargetArg}path/to/test.dart',
    );
    testTarget = target!;

    final argWithTestAppUri =
        args.firstWhereOrNull((arg) => arg.startsWith(testAppArg));
    testAppUri = argWithTestAppUri?.substring(testAppArg.length);

    offline = args.contains(offlineArg);
    enableExperiments = args.contains(enableExperimentsArg);
    updateGoldens = args.contains(updateGoldensArg);
    headless = args.contains(headlessArg);
  }

  static const testTargetArg = '--target=';
  static const testAppArg = '--test-app-uri=';
  static const offlineArg = '--offline';
  static const enableExperimentsArg = '--enable-experiments';
  static const updateGoldensArg = '--update-goldens';
  static const headlessArg = '--headless';

  late final String testTarget;

  /// The Vm Service URI for the test app to connect devtools to.
  ///
  /// This value will only be used when [offline] has not been set to true.
  late final String? testAppUri;

  /// Indicates that a test should not be run with a test app for connecting to
  /// DevTools.
  ///
  /// When [offline] is true, the test will be responsible for loading offline
  /// data to test DevTools against.
  ///
  /// `integration_test/run_tests.dart` will add this flag automatically for
  /// test targets that lives under the integration_test/test/offline directory.
  late final bool offline;

  /// Whether DevTools experiments should be enabled for a test.
  ///
  /// `integration_test/run_tests.dart` will add this flag automatically for
  /// test targets that lives under an `experimental/` directory.
  late final bool enableExperiments;

  /// Whether golden images should be updated with the result of this test run.
  late final bool updateGoldens;

  /// Whether this integration test should be run on the 'web-server' device
  /// instead of 'chrome'.
  late final bool headless;
}
