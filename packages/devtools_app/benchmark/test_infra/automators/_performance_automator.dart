// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: invalid_use_of_visible_for_testing_member, valid use for benchmark tests.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PerformanceScreenAutomator {
  const PerformanceScreenAutomator(this.controller);

  final WidgetController controller;

  Future<void> run() async {
    logStatus('Loading offline performance data and interacting');
    await loadSampleData(controller, performanceLargeFileName);

    // Select a handful of frames.
    final frames = find.byType(FlutterFramesChartItem);
    for (var i = 0; i < 5; i++) {
      await controller.tap(frames.at(i));
      await controller.pump(shortPumpDuration);
    }

    // Open the Timeline Events tab.
    await controller.tap(find.widgetWithText(InkWell, 'Timeline Events'));
    await controller.pump(longPumpDuration);

    // Select more frames.
    for (var i = 5; i < 10; i++) {
      await controller.tap(frames.at(i));
      await controller.pump(shortPumpDuration);
    }

    // Scroll through the frames chart.
    await scrollToEnd<FramesChart>(controller);

    logStatus('End loading offline performance data and interacting');
  }
}
