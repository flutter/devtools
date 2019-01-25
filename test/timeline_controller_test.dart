// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/timeline/timeline_controller.dart';
import 'package:test/test.dart';

import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';

void main() {
  group('TimelineController', () {
    final timelineController = TimelineController();

    final env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    env.afterNewSetup = () async {
      await timelineController.startTimeline();
    };

    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('timeline data not empty', () async {
      await env.setupEnvironment();
      expect(timelineController.timelineData.threads, isNotEmpty);
      expect(timelineController.timelineData.threadMap, isNotEmpty);
      await env.tearDownEnvironment();
    });
  });
}
