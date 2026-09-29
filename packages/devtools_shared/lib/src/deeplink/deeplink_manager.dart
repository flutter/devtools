// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'xcode_build_options.dart';

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

  /// Cached Android build variants keyed by normalized project root path.
  ///
  /// Populated by [getAndroidBuildVariants] and used to validate `buildVariant`
  /// in [getAndroidAppLinkSettings].
  static final _androidBuildVariantsCache = <String, Set<String>>{};

  /// Cached iOS Xcode build options keyed by normalized project root path.
  ///
  /// Populated by [getIosBuildOptions] and used to validate `configuration` and
  /// `target` in [getIosUniversalLinkSettings].
  static final _iosBuildOptionsCache = <String, XcodeBuildOptions>{};

  /// Clears the cached Android build variants and iOS build options.
  @visibleForTesting
  static void clearBuildOptionsCache() {
    _androidBuildVariantsCache.clear();
    _iosBuildOptionsCache.clear();
  }

  // TODO(https://github.com/flutter/devtools/issues/9702): Use the `DashTool`
  // and `DashEnvVar` enums and `getEnvironment()` helper directly from
  // `package:unified_analytics` once the pinned Flutter candidate SDK in this
  // repository is bumped to a stable Dart SDK version >= 3.10.0 (resolving the
  // dev SDK version solving conflict on CI).
  /// Mappings from case-insensitive IDE query parameter values to their
  /// corresponding DashTool canonical label strings used by `package:unified_analytics`.
  ///
  /// Contains multiple spelling and format variations (with/without hyphens
  /// or suffixes) passed by different IDE integrations to ensure O(1) lookup.
  static const _ideToDashToolMap = <String, String>{
    'vs-code': 'vscode-plugins',
    'vscode': 'vscode-plugins',
    'vscodeplugins': 'vscode-plugins',
    'intellij-idea': 'intellij-plugins',
    'intellij': 'intellij-plugins',
    'intellijplugins': 'intellij-plugins',
    'android-studio': 'android-studio-plugins',
    'androidstudio': 'android-studio-plugins',
    'androidstudioplugins': 'android-studio-plugins',
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
    required String workingDirectory,
    required String? ide,
    required bool suppressAnalytics,
  }) {
    final environment = <String, String>{
      ...Platform.environment,
      'DASH__SUPPRESS_ANALYTICS': suppressAnalytics.toString(),
      'DASH__TOOL': ide != null ? _mapIdeToDashToolLabel(ide) : 'devtools',
    };

    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }

  String _mapIdeToDashToolLabel(String ide) {
    final lowerIde = ide.toLowerCase();
    final mappedTool = _ideToDashToolMap[lowerIde];
    if (mappedTool != null) {
      return mappedTool;
    }
    return 'devtools';
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
    required String workingDirectory,
    required RegExp outputMatcher,
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    final flutterPath = getFlutterBinary();
    final result = await runProcess(
      flutterPath,
      arguments: arguments,
      workingDirectory: workingDirectory,
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

  Map<String, Object?> _handleRunFlutterError(Object error) {
    final message = error is _FlutterProcessError
        ? error.message
        : error.toString();
    return <String, String?>{kErrorField: message};
  }

  Future<Map<String, Object?>> _handleReadJsonFile(String filePath) {
    return File(
      filePath,
    ).readAsString().then<Map<String, Object?>>(_handleJsonOutput);
  }

  Future<Map<String, Object?>> _handleJsonOutput(String jsonOutput) async {
    try {
      jsonEncode(jsonOutput);
    } on Error catch (e) {
      return <String, String?>{kErrorField: e.toString()};
    }
    return <String, String?>{kOutputJsonField: jsonOutput};
  }

  Future<Map<String, Object?>> getAndroidBuildVariants({
    required String rootPath,
    String? ide,
    bool suppressAnalytics = false,
  }) {
    final canonicalPath = path.canonicalize(rootPath);
    return _runFlutterCommand(
      <String>['analyze', '--android', '--list-build-variants'],
      workingDirectory: rootPath,
      outputMatcher: _androidBuildVariantJsonRegex,
      ide: ide,
      suppressAnalytics: suppressAnalytics,
    ).then<Map<String, Object?>>((jsonOutput) {
      try {
        final variants = (jsonDecode(jsonOutput) as List)
            .cast<String>()
            .toSet();
        _androidBuildVariantsCache[canonicalPath] = variants;
      } on Object catch (e) {
        return <String, String?>{
          kErrorField: 'Failed to parse Android build variants: $e',
        };
      }
      return _handleJsonOutput(jsonOutput);
    }, onError: _handleRunFlutterError);
  }

  static const _fileIssueMessage =
      'This should not happen; please file an issue at '
      'https://github.com/flutter/devtools/issues.';

  Future<Map<String, Object?>> getAndroidAppLinkSettings({
    required String rootPath,
    required String buildVariant,
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    final canonicalPath = path.canonicalize(rootPath);
    final validVariants = _androidBuildVariantsCache[canonicalPath];
    if (validVariants == null) {
      return <String, String?>{
        kErrorField:
            'Android build variants for "$rootPath" have not been parsed yet. '
            '$_fileIssueMessage',
      };
    }
    if (!validVariants.contains(buildVariant)) {
      return <String, String?>{
        kErrorField:
            'Unknown Android build variant "$buildVariant" for "$rootPath". '
            '$_fileIssueMessage',
      };
    }
    return _runFlutterCommand(
      <String>[
        'analyze',
        '--android',
        '--output-app-link-settings',
        '--build-variant=$buildVariant',
      ],
      workingDirectory: rootPath,
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
    final canonicalPath = path.canonicalize(rootPath);
    return _runFlutterCommand(
      <String>['analyze', '--ios', '--list-build-options'],
      workingDirectory: rootPath,
      outputMatcher: _iosBuildOptionsJsonRegex,
      ide: ide,
      suppressAnalytics: suppressAnalytics,
    ).then<Map<String, Object?>>((jsonOutput) {
      try {
        _iosBuildOptionsCache[canonicalPath] = XcodeBuildOptions.fromJson(
          jsonOutput,
        );
      } on Object catch (e) {
        return <String, String?>{
          kErrorField: 'Failed to parse iOS build options: $e',
        };
      }
      return _handleJsonOutput(jsonOutput);
    }, onError: _handleRunFlutterError);
  }

  Future<Map<String, Object?>> getIosUniversalLinkSettings({
    required String rootPath,
    required String configuration,
    required String target,
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    final canonicalPath = path.canonicalize(rootPath);
    final validOptions = _iosBuildOptionsCache[canonicalPath];
    if (validOptions == null) {
      return <String, String?>{
        kErrorField:
            'iOS build options for "$rootPath" have not been parsed yet. '
            '$_fileIssueMessage',
      };
    }
    if (!validOptions.configurations.contains(configuration) ||
        !validOptions.targets.contains(target)) {
      return <String, String?>{
        kErrorField:
            'Unknown iOS build configuration ($configuration) or target ($target) for "$rootPath". '
            '$_fileIssueMessage',
      };
    }
    return _runFlutterCommand(
      <String>[
        'analyze',
        '--ios',
        '--output-universal-link-settings',
        '--configuration=$configuration',
        '--target=$target',
      ],
      workingDirectory: rootPath,
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
