// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

import 'test_infra/_run_test.dart';

// To run this test, run the following from `devtools_app/`:
// `dart run integration_test/single.dart --target=path/to/test.dart`

Future<void> main(List<String> args) async {
  // The call to [runFlutterIntegrationTest] will fail if a test target has not
  // been provided (e.g. --target=path/to/test.dart).
  final target = args.firstWhereOrNull((arg) => arg.startsWith('--target='));
  final isStandAloneDartTest =
      target?.contains('integration_test/dart_test/') ?? false;
  if (isStandAloneDartTest) {
    await runStandAloneDartTest(args);
  } else {
    await runFlutterIntegrationTest(args);
  }
}
