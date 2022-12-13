// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'test_infra/_run_test.dart';

// To run this test, run the following from `devtools_app/`:
// `dart run integration_test/all.dart`

void main(List<String> args) async {
  const testSuffix = '_test.dart';

  // TODO(kenz): if we end up having several subdirectories under
  // `integration_test/test`, we could allow the directory to be modified with
  // an argument (e.g. --directory=integration_test/test/performance).
  final testDirectory = Directory('integration_test/test');
  final testFiles = testDirectory
      .listSync()
      .where((testFile) => testFile.path.endsWith(testSuffix));
  for (final testFile in testFiles) {
    final testTarget = testFile.path;
    await runTest([...args, '$testTargetArg$testTarget']);
  }
}
