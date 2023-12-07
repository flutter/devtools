// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: invalid_use_of_visible_for_testing_member, valid use for benchmark tests.

import 'package:devtools_app/src/screens/profiler/panes/bottom_up.dart';
import 'package:devtools_app/src/screens/profiler/panes/call_tree.dart';
import 'package:devtools_app/src/screens/profiler/panes/cpu_flame_chart.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CpuProfilerScreenAutomator {
  const CpuProfilerScreenAutomator(this.controller);

  final WidgetController controller;

  Future<void> run() async {
    logStatus('Loading offline CPU profiler data and interacting');
    await loadSampleData(controller, cpuProfilerFileName);

    // At this point we are on the 'Bottom Up' tab. Scroll to the end.
    await scrollToEnd<CpuBottomUpTable>(controller);

    // Switch to all other CPU profiler tabs and scroll to the end.
    await controller.tap(find.widgetWithText(InkWell, 'Call Tree'));
    await controller.pump(shortPumpDuration);
    await scrollToEnd<CpuCallTreeTable>(controller);

    await controller.tap(find.widgetWithText(InkWell, 'Method Table'));
    await controller.pump(shortPumpDuration);
    await scrollToEnd<MethodTable>(controller);

    await controller.tap(find.widgetWithText(InkWell, 'CPU Flame Chart'));
    await controller.pump(shortPumpDuration);
    await scrollToEnd<CpuProfileFlameChart>(controller);

    logStatus('End loading offline CPU profiler data and interacting');
  }
}
