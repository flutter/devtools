// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/test_infra/run/_in_file_args.dart';
import '../../integration_test/test_infra/run/_test_app_driver.dart';

void main() {
  group('$TestFileArgs', () {
    test('empty, flutter app device', () {
      final args = TestFileArgs.fromFileContent(
        '' /* empty file */,
        testAppDevice: TestAppDevice.flutterTester,
      );
      expect(args.experimentsOn, isFalse);
      expect(args.appPath, defaultFlutterAppPath);
    });

    test('empty, cli app device', () {
      final args = TestFileArgs.fromFileContent(
        '' /* empty file */,
        testAppDevice: TestAppDevice.cli,
      );
      expect(args.experimentsOn, isFalse);
      expect(args.appPath, defaultDartCliAppPath);
    });

    test('non-empty', () {
      const testAppPath = 'test/test_infra/fixtures/memory_app';

      final args = TestFileArgs.fromFileContent('''
// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed by test runner.
//test-argument:appPath="$testAppPath"
//   test-argument    :   experimentsOn    =    true


import 'dart:ui' as ui;
''', testAppDevice: TestAppDevice.flutterTester);
      expect(args.experimentsOn, isTrue);
      expect(args.appPath, testAppPath);
    });
  });
}
