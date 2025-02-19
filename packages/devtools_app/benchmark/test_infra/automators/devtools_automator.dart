// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_benchmarks/client.dart';

import '../common.dart';
import '_cpu_profiler_automator.dart';
import '_performance_automator.dart';

/// A class that automates the DevTools web app.
class DevToolsAutomater {
  DevToolsAutomater({
    required this.benchmark,
    required this.stopWarmingUpCallback,
    required this.profile,
  });

  /// The current benchmark.
  final DevToolsBenchmark benchmark;

  /// A function to call when warm-up is finished.
  ///
  /// This function is intended to ask `Recorder` to mark the warm-up phase
  /// as over.
  final void Function() stopWarmingUpCallback;

  /// The profile collected for the running benchmark
  final Profile profile;

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
      defaultScreens(sampleData: sampleData),
      AnalyticsController(
        enabled: false,
        shouldShowConsentMessage: false,
        consentMessage: 'fake message',
      ),
    );
  }

  Future<void> automateDevToolsGestures() async {
    await warmUp();

    switch (benchmark) {
      case DevToolsBenchmark.navigateThroughOfflineScreens:
        await _handleNavigateThroughOfflineScreens();
      case DevToolsBenchmark.offlineCpuProfilerScreen:
        await CpuProfilerScreenAutomator(controller).run();
      case DevToolsBenchmark.offlinePerformanceScreen:
        await PerformanceScreenAutomator(controller).run();
    }

    // Record whether we are in wasm mode or not. Ideally, we'd have a more
    // first-class way to add metadata like this, but this will work for us to
    // pass information about the environment back to the server for the
    // purposes of our own tests.
    profile.extraData['isWasm'] = kIsWasm ? 1 : 0;

    // At the end of the test, mark as finished.
    finished = true;
  }

  /// Warm up the animation.
  Future<void> warmUp() async {
    logStatus('Warming up.');

    // Let animation stop.
    await animationStops();

    // Set controller.
    controller = LiveWidgetController(WidgetsBinding.instance);

    await controller.pumpAndSettle();

    // TODO(kenz): investigate if we need to do something like the Flutter
    // Gallery benchmark tests to warn up the Flutter engine.

    // When warm-up finishes, inform the recorder.
    stopWarmingUpCallback();

    logStatus('Warm-up finished.');
  }

  Future<void> _handleNavigateThroughOfflineScreens() async {
    logStatus('Navigate through offline DevTools tabs');
    await navigateThroughDevToolsScreens(
      controller,
      runWithExpectations: false,
      connectedToApp: false,
    );
    logStatus('End navigate through offline DevTools tabs');
  }
}

const _animationCheckingInterval = Duration(milliseconds: 50);

Future<void> animationStops() async {
  if (!WidgetsBinding.instance.hasScheduledFrame) return;

  final stopped = Completer<void>();

  Timer.periodic(_animationCheckingInterval, (timer) {
    if (!WidgetsBinding.instance.hasScheduledFrame) {
      stopped.complete();
      timer.cancel();
    }
  });

  await stopped.future;
}
