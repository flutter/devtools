// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

const defaultDartExecutable = 'dart';

final defaultFlutterExecutable = Platform.isWindows ? 'flutter.bat' : 'flutter';

class TestAppDriver {
  TestAppDriver() : _flutterExe = _parseFlutterExeFromEnv();

  /// The Flutter executable to use for this test environment.
  ///
  /// This executable can be specified using the --dart-define flag
  /// (e.g. `flutter test --dart-define=FLUTTER_CMD=path/to/flutter/bin/flutter
  /// test/my_test.dart`).
  final String _flutterExe;

  static String _parseFlutterExeFromEnv() {
    const flutterExe = String.fromEnvironment('FLUTTER_CMD');
    return flutterExe.isNotEmpty ? flutterExe : defaultFlutterExecutable;
  }

  final activeProcesses = <Process>[];

  Future<void> runFlutterApp({
    String testAppDirectory = 'test/test_infra/fixtures/flutter_app',
  }) async {
    final process = await Process.start(
      _flutterExe,
      [
        'run',
        '--machine',
      ],
      workingDirectory: testAppDirectory,
    );
  }

  Future<void> runDartCLIApp({
    String testApp = 'test/test_infra/fixtures/empty_app.dart',
  }) async {
    final process = await Process.start(
      defaultDartExecutable,
      [
        '--observe',
        testApp,
      ],
    );
    // This class doesn't use the result of the future. It's made available
    // via a getter for external uses.
    // unawaited(
    //   proc.exitCode.then((int code) {
    //     _debugPrint('Process exited ($code)');
    //     hasExited = true;
    //   }),
    // );
    // transformToLines(proc.stdout)
    //     .listen((String line) => stdoutController.add(line));
    // transformToLines(proc.stderr)
    //     .listen((String line) => stderrController.add(line));

    // // Capture stderr to a buffer so we can show it all if any requests fail.
    // stderrController.stream.listen(errorBuffer.writeln);

    // // This is just debug printing to aid running/debugging tests locally.
    // stdoutController.stream.listen(_debugPrint);
    // stderrController.stream.listen(_debugPrint);
  }

  void shutDownAll() {
    for (final process in activeProcesses) {
      process.kill();
    }
  }
}
