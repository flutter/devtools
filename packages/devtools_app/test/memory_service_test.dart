// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_testing/memory_service_test.dart';
import 'package:devtools_testing/support/flutter_test_driver.dart'
    show FlutterRunConfiguration;
import 'package:devtools_testing/support/flutter_test_environment.dart';
import 'package:test/test.dart';

void main() async {
  // TODO(https://github.com/flutter/devtools/issues/2053): rewrite.
  // ignore: dead_code
  if (false) {
    final FlutterTestEnvironment env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    await runMemoryServiceTests(env);
  }
}
