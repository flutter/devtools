// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/charts/chart.dart';
import '../../../../shared/primitives/memory_timeline.dart';
import '../../controller/charts/android_chart_controller.dart';

class MemoryAndroidChart extends StatefulWidget {
  const MemoryAndroidChart(this.chart, this.memoryTimeline, {super.key});

  final AndroidChartController chart;
  final MemoryTimeline memoryTimeline;

  @override
  MemoryAndroidChartState createState() => MemoryAndroidChartState();
}

class MemoryAndroidChartState extends State<MemoryAndroidChart>
    with AutoDisposeMixin {
  /// Controller attached to the chart.
  AndroidChartController get _chartController => widget.chart;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant MemoryAndroidChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoryTimeline == widget.memoryTimeline) return;
    _init();
  }

  void _init() {
    cancelListeners();
    addAutoDisposeListener(widget.chart.traceChanged);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultChartHeight,
      child: Chart(_chartController),
    );
  }
}
