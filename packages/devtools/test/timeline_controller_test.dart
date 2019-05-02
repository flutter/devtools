// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/timeline/timeline_controller.dart';
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

    // TODO(kenzie): uncomment these methods once we have proper data from the
    //  engine or have a way to handle events from the test device.

//    tearDownAll(() async {
//      await env.tearDownEnvironment(force: true);
//    });
//
//    test('timeline data not empty', () async {
//      await env.setupEnvironment();
//      expect(timelineController.timelineData.frames, isNotEmpty);
//      expect(timelineController.timelineData.frames, isNotEmpty);
//      await env.tearDownEnvironment();
//    });

    // TODO(kenzie): add more tests. We will be able to once we have the proper
    //  data from the engine, allowing us to distinguish cpu events from gpu
    //  events as well as to know accurate frame start times, end times, and
    //  events.
  }, tags: 'useFlutterSdk');
}
