// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/test_infra/run/_in_file_args.dart';

const _testAppPath = 'test/test_infra/fixtures/memory_app';

late final _defaultArgs = InFileArgs.private({});

final tests = [
  _InFileTestArgsTest(
    name: 'empty',
    input: '',
    output: InFileArgs.private({
      InFileArgItems.experimentsOn: _defaultArgs.experimentsOn,
      InFileArgItems.appPath: _defaultArgs.appPath,
    }),
  ),
  _InFileTestArgsTest(
    name: 'non-empty',
    input: '''
// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Do not delete these arguments. They are parsed parsed by test runner.
// test-argument:experimentsOn=true
// test-argument:appPath="$_testAppPath"

import 'dart:ui' as ui;
''',
    output: InFileArgs.private({
      InFileArgItems.experimentsOn: true,
      InFileArgItems.appPath: _testAppPath,
    }),
  ),
];

void main() {
  for (final t in tests) {
    test('$InFileArgs, ${t.name}', () {
      final args = InFileArgs.fromFileContent(t.input);
      expect(args.experimentsOn, t.output.experimentsOn);
      expect(args.appPath, t.output.appPath);
    });
  }
}

class _InFileTestArgsTest {
  _InFileTestArgsTest({
    required this.name,
    required this.input,
    required this.output,
  });

  final String name;
  final String input;
  final InFileArgs output;
}
