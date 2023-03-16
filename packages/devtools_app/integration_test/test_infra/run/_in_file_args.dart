// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

enum InFileArgItems {
  experimentsOn,
  appPath,
}

/// Test arguments, defined inside the test file as a comment.
class TestFileArgs {
  factory TestFileArgs(String testFilePath) {
    final content = File(testFilePath).readAsStringSync();
    return TestFileArgs.fromFileContent(content);
  }

  factory TestFileArgs.fromFileContent(String fileContent) {
    final values = _parseFileContent(fileContent);

    for (final arg in values.keys) {
      values.putIfAbsent(arg, () => null);
    }

    return TestFileArgs.fromValues(values);
  }

  TestFileArgs.fromValues(Map<InFileArgItems, dynamic> values)
      : experimentsOn = values[InFileArgItems.experimentsOn] ?? false,
        appPath = values[InFileArgItems.appPath] ??
            'test/test_infra/fixtures/flutter_app';

  /// If true, experiments will be enabled in the test.
  final bool experimentsOn;

  /// Path to the application to connect to.
  final String appPath;
}

final _argRegex = RegExp(
  r'^\/\/\s*test-argument\s*:\s*(\w*)\s*=\s*(\S*)\s*$',
  multiLine: true,
);

Map<InFileArgItems, dynamic> _parseFileContent(String fileContent) {
  final matches = _argRegex.allMatches(fileContent);

  final entries = matches.map<MapEntry<InFileArgItems, dynamic>>(
    (RegExpMatch m) {
      final name = m.group(1) ?? '';
      if (name.isEmpty)
        throw 'Name of test argument name should be provided: [${m.group(0)}].';
      final value = m.group(2) ?? '';
      return MapEntry(InFileArgItems.values.byName(name), jsonDecode(value));
    },
  );

  return Map.fromEntries(entries);
}
