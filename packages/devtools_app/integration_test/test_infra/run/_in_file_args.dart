// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import '_test_app_driver.dart';

enum TestFileArgItems {
  experimentsOn,
  appPath,
}

const _defaultFlutterAppPath = 'test/test_infra/fixtures/flutter_app';
const _defaultDartCliAppPath = 'test/test_infra/fixtures/empty_app.dart';

/// Test arguments, defined inside the test file as a comment.
class TestFileArgs {
  factory TestFileArgs(
    String testFilePath, {
    required TestAppDevice testAppDevice,
  }) {
    final content = File(testFilePath).readAsStringSync();
    return TestFileArgs.fromFileContent(content, testAppDevice: testAppDevice);
  }

  factory TestFileArgs.fromFileContent(
    String fileContent, {
    required TestAppDevice testAppDevice,
  }) {
    final testFileArgItems = _parseFileContent(fileContent);

    for (final arg in testFileArgItems.keys) {
      testFileArgItems.putIfAbsent(arg, () => null);
    }

    return TestFileArgs.parse(testFileArgItems, testAppDevice: testAppDevice);
  }

  TestFileArgs.parse(
    Map<TestFileArgItems, dynamic> map, {
    required TestAppDevice testAppDevice,
  })  : experimentsOn = map[TestFileArgItems.experimentsOn] ?? false,
        appPath = map[TestFileArgItems.appPath] ??
            (testAppDevice == TestAppDevice.cli
                ? _defaultDartCliAppPath
                : _defaultFlutterAppPath);

  /// If true, experiments will be enabled in the test.
  final bool experimentsOn;

  /// Path to the application to connect to.
  final String appPath;
}

final _argRegex = RegExp(
  r'^\/\/\s*test-argument\s*:\s*(\w*)\s*=\s*(\S*)\s*$',
  multiLine: true,
);

Map<TestFileArgItems, dynamic> _parseFileContent(String fileContent) {
  final matches = _argRegex.allMatches(fileContent);

  final entries = matches.map<MapEntry<TestFileArgItems, dynamic>>(
    (RegExpMatch m) {
      final name = m.group(1) ?? '';
      if (name.isEmpty) {
        throw ArgumentError(
          'Name of test argument should be provided: [${m.group(0)}].',
        );
      }
      final value = m.group(2) ?? '';
      return MapEntry(TestFileArgItems.values.byName(name), jsonDecode(value));
    },
  );

  return Map.fromEntries(entries);
}
