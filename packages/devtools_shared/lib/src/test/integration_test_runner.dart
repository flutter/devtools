// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'chrome_driver.dart';
import 'io_utils.dart';

const _testSuffix = '_test.dart';

class IntegrationTestRunner with IOMixin {
  static const _beginExceptionMarker = 'EXCEPTION CAUGHT';
  static const _endExceptionMarker = '═════════════════════════';
  static const _errorMarker = ': Error: ';
  static const _unhandledExceptionMarker = 'Unhandled exception:';
  static const _allTestsPassed = 'All tests passed!';
  static const _maxRetriesOnTimeout = 1;

  Future<void> run(
    String testTarget, {
    required String testDriver,
    bool headless = false,
    List<String> dartDefineArgs = const <String>[],
    bool debugLogging = false,
  }) async {
    void debugLog(String log) {
      if (debugLogging) print(log);
    }

    Future<void> runTest({required int attemptNumber}) async {
      debugLog('starting the flutter drive process');
      final process = await Process.start(
        'flutter',
        [
          'drive',
          // Debug outputs from the test will not show up in profile mode. Since
          // we rely on debug outputs for detecting errors and exceptions from the
          // test, we cannot run this these tests in profile mode until this issue
          // is resolved.  See https://github.com/flutter/flutter/issues/69070.
          // '--profile',
          '--driver=$testDriver',
          '--target=$testTarget',
          '-d',
          headless ? 'web-server' : 'chrome',
          for (final arg in dartDefineArgs) '--dart-define=$arg',
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

          if (line.startsWith(_IntegrationTestResult.testResultPrefix)) {
            final testResultJson = line.substring(line.indexOf('{'));
            final testResultMap =
                jsonDecode(testResultJson) as Map<String, Object?>;
            final result = _IntegrationTestResult.parse(testResultMap);
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

      debugLog('attempting to kill the flutter drive process');
      process.kill();
      debugLog('flutter drive process has exited');

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
            debugLog(
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

class _IntegrationTestResult {
  _IntegrationTestResult._(this.result, this.methodName, this.details);

  factory _IntegrationTestResult.parse(Map<String, Object?> json) {
    final result = json[resultKey] == 'true';
    final failureDetails =
        (json[failureDetailsKey] as List<Object?>).cast<String>().firstOrNull ??
            '{}';
    final failureDetailsMap =
        jsonDecode(failureDetails) as Map<String, Object?>;
    final methodName = failureDetailsMap[methodNameKey] as String?;
    final details = failureDetailsMap[detailsKey] as String?;
    return _IntegrationTestResult._(result, methodName, details);
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

class IntegrationTestRunnerArgs {
  IntegrationTestRunnerArgs(
    List<String> args, {
    bool verifyValidTarget = true,
    void Function(ArgParser)? addExtraArgs,
  }) {
    final argParser = buildArgParser(addExtraArgs: addExtraArgs);
    argResults = argParser.parse(args);
    rawArgs = args;

    if (verifyValidTarget) {
      final target = argResults[testTargetArg];
      assert(
        target != null,
        'Please specify a test target (e.g. '
        '--$testTargetArg=path/to/test.dart',
      );
    }
  }

  @protected
  late final ArgResults argResults;

  late final List<String> rawArgs;

  /// The path to the test target.
  String? get testTarget => argResults[testTargetArg];

  /// Whether this integration test should be run on the 'web-server' device
  /// instead of 'chrome'.
  bool get headless => argResults[_headlessArg];

  /// Sharding information for this test run.
  ({int shardNumber, int totalShards})? get shard {
    final shardValue = argResults[_shardArg];
    if (shardValue != null) {
      final shardParts = shardValue.split('/');
      if (shardParts.length == 2) {
        final shardNumber = int.tryParse(shardParts[0]);
        final totalShards = int.tryParse(shardParts[1]);
        if (shardNumber is int && totalShards is int) {
          return (shardNumber: shardNumber, totalShards: totalShards);
        }
      }
    }
    return null;
  }

  /// Whether the help flag `-h` was passed to the integration test command.
  bool get help => argResults[_helpArg];

  void printHelp() {
    print('Run integration tests (one or many) for the Dart DevTools package.');
    print(buildArgParser().usage);
  }

  static const _helpArg = 'help';
  static const testTargetArg = 'target';
  static const _headlessArg = 'headless';
  static const _shardArg = 'shard';

  /// Builds an arg parser for DevTools integration tests.
  static ArgParser buildArgParser({
    void Function(ArgParser)? addExtraArgs,
  }) {
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
      ..addFlag(
        _headlessArg,
        negatable: false,
        help:
            'Runs the integration test on the \'web-server\' device instead of '
            'the \'chrome\' device. For headless test runs, you will not be '
            'able to see the integration test run visually in a Chrome browser.',
      )
      ..addOption(
        _shardArg,
        valueHelp: '1/3',
        help: 'The shard number for this run out of the total number of shards '
            '(e.g. 1/3)',
      );
    addExtraArgs?.call(argParser);
    return argParser;
  }
}

Future<void> runOneOrManyTests<T extends IntegrationTestRunnerArgs>({
  required String testDirectoryPath,
  required T testRunnerArgs,
  required Future<void> Function(T) runTest,
  required T Function(List<String>) newArgsGenerator,
  bool Function(FileSystemEntity)? testIsSupported,
  bool debugLogging = false,
}) async {
  if (testRunnerArgs.help) {
    testRunnerArgs.printHelp();
    return;
  }

  final chromedriver = ChromeDriver();

  try {
    // Start chrome driver before running the flutter integration test.
    await chromedriver.start(debugLogging: debugLogging);

    if (testRunnerArgs.testTarget != null) {
      // TODO(kenz): add support for specifying a directory as the target instead
      // of a single file.
      await runTest(testRunnerArgs);
    } else {
      // Run all supported tests since a specific target test was not provided.
      final testDirectory = Directory(testDirectoryPath);
      var testFiles = testDirectory
          .listSync(recursive: true)
          .where(
            (testFile) =>
                testFile.path.endsWith(_testSuffix) &&
                (testIsSupported?.call(testFile) ?? true),
          )
          .toList();

      final shard = testRunnerArgs.shard;
      if (shard != null) {
        final shardSize = testFiles.length ~/ shard.totalShards;
        // Subtract 1 since the [shard.shardNumber] index is 1-based.
        final shardStart = (shard.shardNumber - 1) * shardSize;
        final shardEnd = shard.shardNumber == shard.totalShards
            ? null
            : shardStart + shardSize;
        testFiles = testFiles.sublist(shardStart, shardEnd);
      }

      for (final testFile in testFiles) {
        final testTarget = testFile.path;
        final newArgsWithTarget = newArgsGenerator([
          ...testRunnerArgs.rawArgs,
          '--${IntegrationTestRunnerArgs.testTargetArg}=$testTarget',
        ]);
        await runTest(newArgsWithTarget);
      }
    }
  } finally {
    await chromedriver.stop(debugLogging: debugLogging);
  }
}
