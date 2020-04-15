// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_testing/support/flutter_test_driver.dart'
    show FlutterRunConfiguration;
import 'package:devtools_testing/support/flutter_test_environment.dart';
import 'package:devtools_testing/timeline_controller_test.dart';
@TestOn('vm')
import 'package:test/test.dart';

void main() async {
  // TODO(devoncarew): Skip the timeline_controller_test.dart tests (#1778).
  // ignore: dead_code
  if (false) {
    final FlutterTestEnvironment env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    await runTimelineControllerTests(env);
  }
}
