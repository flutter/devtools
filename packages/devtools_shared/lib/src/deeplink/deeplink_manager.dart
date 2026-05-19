// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:unified_analytics/unified_analytics.dart';

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

  /// Mappings from case-insensitive IDE query parameter values to their
  /// corresponding [DashTool] enum values used by `package:unified_analytics`.
  ///
  /// Contains multiple spelling and format variations (with/without hyphens
  /// or suffixes) passed by different IDE integrations to ensure O(1) lookup.
  static const _ideToDashToolMap = <String, DashTool>{
    'vs-code': DashTool.vscodePlugins,
    'vscode': DashTool.vscodePlugins,
    'vscodeplugins': DashTool.vscodePlugins,
    'intellij-idea': DashTool.intellijPlugins,
    'intellij': DashTool.intellijPlugins,
    'intellijplugins': DashTool.intellijPlugins,
    'android-studio': DashTool.androidStudioPlugins,
    'androidstudio': DashTool.androidStudioPlugins,
    'androidstudioplugins': DashTool.androidStudioPlugins,
  };

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
    String? ide,
    bool suppressAnalytics = false,
  }) {
    final environment = getEnvironment(
      currentTool: ide != null ? _mapIdeToDashTool(ide) : DashTool.devtools,
      suppressAnalytics: suppressAnalytics,
    );

    return Process.run(
      executable,
      arguments,
      environment: environment,
    );
  }

  DashTool _mapIdeToDashTool(String ide) {
    final lowerIde = ide.toLowerCase();
    final mappedTool = _ideToDashToolMap[lowerIde];
    if (mappedTool != null) {
      return mappedTool;
    }

    for (final value in DashTool.values) {
      if (value.name.toLowerCase() == lowerIde) {
        return value;
      }
    }
    return DashTool.devtools;
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
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    final flutterPath = getFlutterBinary();
    final result = await runProcess(
      flutterPath,
      arguments: arguments,
      ide: ide,
      suppressAnalytics: suppressAnalytics,
    );
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

  Future<Map<String, Object?>> _handleReadJsonFile(String filePath) {
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
    String? ide,
    bool suppressAnalytics = false,
  }) {
    return _runFlutterCommand(
      <String>['analyze', '--android', '--list-build-variants', rootPath],
      outputMatcher: _androidBuildVariantJsonRegex,
      ide: ide,
      suppressAnalytics: suppressAnalytics,
    ).then<Map<String, Object?>>(
      _handleJsonOutput,
      onError: _handleRunFlutterError,
    );
  }

  Future<Map<String, Object?>> getAndroidAppLinkSettings({
    required String rootPath,
    required String buildVariant,
    String? ide,
    bool suppressAnalytics = false,
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
      ide: ide,
      suppressAnalytics: suppressAnalytics,
    ).then<Map<String, Object?>>(
      _handleReadJsonFile,
      onError: _handleRunFlutterError,
    );
  }

  Future<Map<String, Object?>> getIosBuildOptions({
    required String rootPath,
    String? ide,
    bool suppressAnalytics = false,
  }) {
    return _runFlutterCommand(
      <String>['analyze', '--ios', '--list-build-options', rootPath],
      outputMatcher: _iosBuildOptionsJsonRegex,
      ide: ide,
      suppressAnalytics: suppressAnalytics,
    ).then<Map<String, Object?>>(
      _handleJsonOutput,
      onError: _handleRunFlutterError,
    );
  }

  Future<Map<String, Object?>> getIosUniversalLinkSettings({
    required String rootPath,
    required String configuration,
    required String target,
    String? ide,
    bool suppressAnalytics = false,
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
      ide: ide,
      suppressAnalytics: suppressAnalytics,
    ).then<Map<String, Object?>>(
      _handleReadJsonFile,
      onError: _handleRunFlutterError,
    );
  }
}

class _FlutterProcessError extends Error {
  _FlutterProcessError(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'Error: $message';
}
