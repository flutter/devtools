// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scroll.dart';

/// A class that automates the DevTools web app.
class DevToolsAutomater {
  DevToolsAutomater({
    required this.benchmarkName,
    required this.stopWarmingUpCallback,
  });

  /// The name of the current benchmark.
  final String benchmarkName;

  /// A function to call when warm-up is finished.
  ///
  /// This function is intended to ask `Recorder` to mark the warm-up phase
  /// as over.
  final void Function() stopWarmingUpCallback;

  /// Whether the automation has ended.
  bool finished = false;

  /// A widget controller for automation.
  late LiveWidgetController controller;

  /// The [DevToolsApp] widget with automation.
  Widget createWidget() {
    // There is no `catchError` here, because all errors are caught by
    // the zone set up in `lib/web_benchmarks.dart` in `flutter/flutter`.
    Future<void>.delayed(safePumpDuration, automateDevToolsGestures);
    return DevToolsApp(
      defaultScreens(),
      AnalyticsController(enabled: false, firstRun: false),
    );
  }

  Future<void> automateDevToolsGestures() async {
    await warmUp();

    _logStatus('==== Navigate through DevTools tabs ====');
    await navigateThroughDevToolsScreens(
      controller,
      runWithExpectations: false,
    );
    _logStatus('==== End of navigate through DevTools tabs ====');

    // At the end of the test, mark as finished.
    finished = true;
  }

  /// Warm up the animation.
  Future<void> warmUp() async {
    _logStatus('Warming up.');

    // Let animation stop.
    await animationStops();

    // Set controller.
    controller = LiveWidgetController(WidgetsBinding.instance);

    await controller.pumpAndSettle();

    // TODO(kenz): investigate if we need to do something like the Flutter
    // Gallery benchmark tests to warn up the Flutter engine.

    // When warm-up finishes, inform the recorder.
    stopWarmingUpCallback();

    _logStatus('Warm-up finished.');
  }
}

void _logStatus(String log) {
  // ignore: avoid_print, intentional test logging.
  print(log);
}
