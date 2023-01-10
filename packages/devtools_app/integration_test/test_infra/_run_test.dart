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
  TestArgs testRunnerArgs, {
  String testAppPath = 'test/test_infra/fixtures/flutter_app',
}) async {
  TestFlutterApp? testApp;
  late String testAppUri;

  final bool shouldCreateTestApp = testRunnerArgs.testAppUri == null;
  if (shouldCreateTestApp) {
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
  try {
    await testRunner.run(
      testRunnerArgs.testTarget,
      enableExperiments: testRunnerArgs.enableExperiments,
      headless: testRunnerArgs.headless,
      testAppArguments: {
        'service_uri': testAppUri,
      },
    );
  } catch (_) {
    rethrow;
  } finally {
    if (shouldCreateTestApp) {
      _debugLog('killing the test app');
      await testApp?.stop();
    }

    _debugLog('cancelling stream subscriptions');
    await testRunner.cancelAllStreamSubscriptions();
    await chromedriver.cancelAllStreamSubscriptions();

    _debugLog('killing the chromedriver process');
    chromedriver.kill();
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
    listenToProcessOutput(
      process,
      onStdout: (line) {
        if (line.startsWith(_TestResult.testResultPrefix)) {
          final testResultJson = line.substring(line.indexOf('{'));
          final testResultMap =
              jsonDecode(testResultJson) as Map<String, Object?>;
          final result = _TestResult.parse(testResultMap);
          if (!result.result) {
            throw Exception(result.toString());
          }
        }
        print('stdout = $line');
      },
    );

    await process.exitCode;
    process.kill();
    _debugLog('flutter drive process has exited');
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
