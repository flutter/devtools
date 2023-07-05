// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/test_infra/run/_in_file_args.dart';
import '../../integration_test/test_infra/run/_test_app_driver.dart';

const _testAppPath = 'test/test_infra/fixtures/memory_app';

final _defaultArgs = TestFileArgs.parse(
  {},
  testAppDevice: TestAppDevice.flutterTester,
);

final _defaultArgsForCliDevice = TestFileArgs.parse(
  {},
  testAppDevice: TestAppDevice.cli,
);

final tests = [
  _InFileTestArgsTest(
    name: 'empty',
    input: '',
    testAppDevice: TestAppDevice.flutterTester,
    output: TestFileArgs.parse(
      {
        TestFileArgItems.experimentsOn: _defaultArgs.experimentsOn,
        TestFileArgItems.appPath: _defaultArgs.appPath,
      },
      testAppDevice: TestAppDevice.flutterTester,
    ),
  ),
  _InFileTestArgsTest(
    name: 'empty',
    input: '',
    testAppDevice: TestAppDevice.cli,
    output: TestFileArgs.parse(
      {
        TestFileArgItems.experimentsOn: _defaultArgsForCliDevice.experimentsOn,
        TestFileArgItems.appPath: _defaultArgsForCliDevice.appPath,
      },
      testAppDevice: TestAppDevice.cli,
    ),
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
    output: TestFileArgs.parse(
      {
        TestFileArgItems.experimentsOn: true,
        TestFileArgItems.appPath: _testAppPath,
      },
      testAppDevice: TestAppDevice.flutterTester,
    ),
  ),
];

void main() {
  for (final t in tests) {
    test('$TestFileArgs, ${t.name}', () {
      final args = TestFileArgs.fromFileContent(
        t.input,
        testAppDevice: t.testAppDevice,
      );
      expect(args.experimentsOn, t.output.experimentsOn);
      expect(args.appPath, t.output.appPath);
    });
  }
}

class _InFileTestArgsTest {
  _InFileTestArgsTest({
    required this.name,
    required this.input,
    required this.testAppDevice,
    required this.output,
  });

  final String name;
  final String input;
  final TestAppDevice testAppDevice;
  final TestFileArgs output;
}
