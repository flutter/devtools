// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/test_infra/run/_in_file_args.dart';
import '../../integration_test/test_infra/run/_test_app_driver.dart';

const _testAppPath = 'test/test_infra/fixtures/memory_app';

final _defaultArgs = TestFileArgs.fromFileContent(
  '',
  testAppDevice: TestAppDevice.flutterTester,
);

final _defaultArgsForCliDevice = TestFileArgs.fromFileContent(
  '',
  testAppDevice: TestAppDevice.cli,
);

final tests = [
  _InFileTestArgsTest(
    name: 'empty',
    input: '',
    testAppDevice: TestAppDevice.flutterTester,
    expectedExperimentsOn: _defaultArgs.experimentsOn,
    expectedAppPath: _testAppPath,
  ),
  _InFileTestArgsTest(
    name: 'empty',
    input: '',
    testAppDevice: TestAppDevice.cli,
    expectedExperimentsOn: _defaultArgsForCliDevice.experimentsOn,
    expectedAppPath: _testAppPath,
  ),
  _InFileTestArgsTest(
    name: 'non-empty',
    input: '''
// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed by test runner.
//test-argument:appPath="$_testAppPath"
//   test-argument    :   experimentsOn    =    true


import 'dart:ui' as ui;
''',
    testAppDevice: TestAppDevice.flutterTester,
    expectedExperimentsOn: true,
    expectedAppPath: _testAppPath,
  ),
];

void main() {
  for (final t in tests) {
    test('$TestFileArgs, ${t.name}', () {
      final args = TestFileArgs.fromFileContent(
        t.input,
        testAppDevice: t.testAppDevice,
      );
      expect(args.experimentsOn, t.expectedExperimentsOn);
      expect(args.appPath, t.expectedAppPath);
    });
  }
}

class _InFileTestArgsTest {
  _InFileTestArgsTest({
    required this.name,
    required this.input,
    required this.testAppDevice,
    required this.expectedExperimentsOn,
    required this.expectedAppPath,
  });

  final String name;
  final String input;
  final TestAppDevice testAppDevice;
  final bool expectedExperimentsOn;
  final String expectedAppPath;
}
