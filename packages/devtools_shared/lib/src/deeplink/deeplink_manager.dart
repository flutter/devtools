// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

class DeeplinkManager {
  /// A regex to retrieve the json part from the stdout of Android analyzer.
  ///
  /// Example stdout:
  ///
  /// Running Gradle task 'printBuildVariants'...                        10.4s
  /// ["debug","release","profile"]
  static final _androidBuildVariantJsonRegex = RegExp(r'(\[.*\])');

  /// A regex to retrieve the json part of the stdout of iOS analyzer.
  ///
  /// Example stdout:
  ///
  /// {"configurations":["Debug","Release","Profile"],"targets":["Runner","RunnerTests"]}
  static final _iosBuildOptionsJsonRegex = RegExp(r'({.*})');

  /// The key to retrieve error message from the returning map of this class's
  /// APIs.
  static const kErrorField = 'error';

  /// The key to retrieve output json from the returning map of this class's
  /// APIs.
  static const kOutputJsonField = 'json';

  /// A regex to retrieve the file path from the stdout of iOS or Android
  /// analyzers.
  ///
  /// Example stdout:
  ///
  /// result saved in /path/to/json/file.json
  static final _outputFilePathRegex = RegExp(r'result saved in (.*.json)');

  @visibleForTesting
  Future<ProcessResult> runProcess(
    String executable, {
    required List<String> arguments,
  }) {
    return Process.run(
      executable,
      arguments,
    );
  }

  @visibleForTesting
  String getFlutterBinary() {
    // FLUTTER_ROOT can be set by Dart-Code VSCode extension or dart shell
    // script shipped with flutter sdk.
    var flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) {
      // Attempt to find flutter root from dart binary path.
      final dartPathSegments = path.split(Platform.resolvedExecutable);
      final flutterFolderSegmentIndex = dartPathSegments.lastIndexOf('flutter');
      if (flutterFolderSegmentIndex != -1 &&
          dartPathSegments[flutterFolderSegmentIndex + 1] == 'bin') {
        flutterRoot = path.joinAll(
          dartPathSegments.sublist(0, flutterFolderSegmentIndex + 1),
        );
      }
    }
    if (flutterRoot == null) {
      // Fallback to use flutter from PATH.
      return Platform.isWindows ? 'flutter.bat' : 'flutter';
    }
    return path.join(
      flutterRoot,
      'bin',
      Platform.isWindows ? 'flutter.bat' : 'flutter',
    );
  }

  Future<String> _runFlutterCommand(
    List<String> arguments, {
    required RegExp outputMatcher,
  }) async {
    final flutterPath = getFlutterBinary();
    final result = await runProcess(flutterPath, arguments: arguments);
    if (result.exitCode != 0) {
      throw _FlutterProcessError(
        'Flutter command exit with non-zero error code ${result.exitCode}\n${result.stderr}',
      );
    }
    final match = outputMatcher.firstMatch(result.stdout);
    if (match == null) {
      throw _FlutterProcessError("Can't parse output: ${result.stdout}");
    } else {
      return match.group(1)!; //await File(match.group(1)!).readAsString();
    }
  }

  Map<String, Object?> _handleRunFlutterError(
    covariant _FlutterProcessError error,
  ) {
    return <String, String?>{
      kErrorField: error.message,
    };
  }

  Future<Map<String, Object?>> _handleReadJsonFile(String filePath) async {
    return File(filePath)
        .readAsString()
        .then<Map<String, Object?>>(_handleJsonOutput);
  }

  Future<Map<String, Object?>> _handleJsonOutput(String jsonOutput) async {
    try {
      jsonEncode(jsonOutput);
    } on Error catch (e) {
      return <String, String?>{
        kErrorField: e.toString(),
      };
    }
    return <String, String?>{
      kOutputJsonField: jsonOutput,
    };
  }

  Future<Map<String, Object?>> getAndroidBuildVariants({
    required String rootPath,
  }) async {
    return _runFlutterCommand(
      <String>['analyze', '--android', '--list-build-variants', rootPath],
      outputMatcher: _androidBuildVariantJsonRegex,
    ).then<Map<String, Object?>>(
      _handleJsonOutput,
      onError: _handleRunFlutterError,
    );
  }

  Future<Map<String, Object?>> getAndroidAppLinkSettings({
    required String rootPath,
    required String buildVariant,
  }) {
    return _runFlutterCommand(
      <String>[
        'analyze',
        '--android',
        '--output-app-link-settings',
        '--build-variant=$buildVariant',
        rootPath,
      ],
      outputMatcher: _outputFilePathRegex,
    ).then<Map<String, Object?>>(
      _handleReadJsonFile,
      onError: _handleRunFlutterError,
    );
  }

  Future<Map<String, Object?>> getIosBuildOptions({
    required String rootPath,
  }) async {
    return _runFlutterCommand(
      <String>['analyze', '--ios', '--list-build-options', rootPath],
      outputMatcher: _iosBuildOptionsJsonRegex,
    ).then<Map<String, Object?>>(
      _handleJsonOutput,
      onError: _handleRunFlutterError,
    );
  }

  Future<Map<String, Object?>> getIosUniversalLinkSettings({
    required String rootPath,
    required String configuration,
    required String target,
  }) {
    return _runFlutterCommand(
      <String>[
        'analyze',
        '--ios',
        '--output-universal-link-settings',
        '--configuration=$configuration',
        '--target=$target',
        rootPath,
      ],
      outputMatcher: _outputFilePathRegex,
    ).then<Map<String, Object?>>(
      _handleReadJsonFile,
      onError: _handleRunFlutterError,
    );
  }
}

class _FlutterProcessError extends Error {
  /// Constructs a [GoError]
  _FlutterProcessError(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'Error: $message';
}
