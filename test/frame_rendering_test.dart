// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';

import 'package:devtools/globals.dart';
import 'package:devtools/service_extensions.dart' as extensions;
import 'package:devtools/timeline/frame_rendering.dart';
import 'package:test/test.dart';

import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';

void main() {
  group('frame rendering tests', () {
    FramesTracker framesTracker;

    final FlutterTestEnvironment env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    env.afterNewSetup = () {
      framesTracker = FramesTracker(env.service);
      framesTracker.start();
      expect(framesTracker.eventStreamSubscription, isNotNull);
      expect(framesTracker.samples, isEmpty);

      // Reset this value to true so that the first call to _forceDrawFrame will
      // turn the performance overlay on.
      showPerformanceOverlay = true;
    };
    env.beforeTearDown = () {
      framesTracker.stop();
      expect(framesTracker.eventStreamSubscription, isNull);
    };

    test('FramesTracker tracks frames', () async {
      await env.setupEnvironment();

      await _forceDrawFrame();
      expect(framesTracker.samples, isNotEmpty);
      expect(framesTracker.samples.length, equals(1));

      await env.tearDownEnvironment();
    });

    test('FramesTracker pauses and resumes', () async {
      await env.setupEnvironment();

      framesTracker.pause();
      expect(framesTracker.eventStreamSubscription.isPaused, isTrue);

      await _forceDrawFrame();
      expect(framesTracker.samples.length, equals(1));

      framesTracker.resume();
      expect(framesTracker.eventStreamSubscription.isPaused, isFalse);

      await _forceDrawFrame();
      expect(framesTracker.samples.length, equals(2));

      await env.tearDownEnvironment();
    });

    test('FramesTracker calcRecentFPS', () async {
      await env.setupEnvironment();

      framesTracker.samples = _fakeSamplesForLowFPS;
      expect(framesTracker.calcRecentFPS(), equals(29.999999999999996));
      expect(framesTracker.calcRecentFPS().round(), equals(30));

      framesTracker.samples = _fakeSamplesFor60FPS;
      expect(framesTracker.calcRecentFPS(), equals(59.99999999999999));
      expect(framesTracker.calcRecentFPS().round(), equals(60));

      await env.tearDownEnvironment(force: true);
    });
  }, tags: 'useFlutterSdk');
}

bool showPerformanceOverlay = true;

/// Forces a frame to be drawn by toggling the performance overlay service
/// extension.
Future<void> _forceDrawFrame() async {
  // Call a service extension that will force a frame to be drawn.
  await serviceManager.serviceExtensionManager.setServiceExtensionState(
    extensions.performanceOverlay.extension,
    showPerformanceOverlay,
    showPerformanceOverlay,
  );
  showPerformanceOverlay = false;
}

final List<FrameInfo> _fakeSamplesForLowFPS = [
  FrameInfo(1, 20, 0),
  FrameInfo(2, 20, 20),
  FrameInfo(3, 20, 40),
  FrameInfo(4, 20, 60),
  FrameInfo(5, 20, 80),
];

final List<FrameInfo> _fakeSamplesFor60FPS = [
  FrameInfo(1, 16, 0),
  FrameInfo(2, 16, 16),
  FrameInfo(3, 16, 32),
  FrameInfo(4, 16, 48),
  FrameInfo(5, 16, 64),
];
