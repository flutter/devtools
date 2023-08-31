// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

class DeeplinkManager {
  /// A regex to retrieve the json part of the stdout.
  ///
  /// Example stdout:
  ///
  /// Running Gradle task 'printBuildVariants'...                        10.4s
  /// ["debug","release","profile"]
  static final _buildVariantJsonRegex = RegExp(r'(\[.*\])');
  static const kErrorField = 'error';
  static const kOutputJsonField = 'json';

  @visibleForTesting
  Future<ProcessResult> runProcess(String executable, List<String> arguments) {
    return Process.run(executable, arguments);
  }

  Future<Map<String, Object?>> getBuildVariants({
    required String rootPath,
  }) async {
    final ProcessResult result = await runProcess(
      'flutter',
      <String>['analyze', '--android', '--list-build-variants', rootPath],
    );
    if (result.exitCode != 0) {
      return <String, String>{
        kErrorField:
            'Flutter command exit with non-zero error code ${result.exitCode}\n${result.stderr}',
      };
    }
    final match = _buildVariantJsonRegex.firstMatch(result.stdout);
    final String outputJson;
    if (match == null) {
      outputJson = '[]';
    } else {
      outputJson = match.group(1)!;
    }
    try {
      jsonEncode(outputJson);
    } on Error catch (e) {
      return <String, String?>{
        kErrorField: e.toString(),
      };
    }
    return <String, String?>{
      kErrorField: null,
      kOutputJsonField: outputJson,
    };
  }
}
