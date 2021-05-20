// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_testing/provider/provider_controller_test.dart';
import 'package:devtools_testing/support/flutter_test_driver.dart'
    show FlutterRunConfiguration;
import 'package:devtools_testing/support/flutter_test_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
    testAppDirectory: 'fixtures/provider_app',
  );

  await runProviderControllerTests(env);
}
