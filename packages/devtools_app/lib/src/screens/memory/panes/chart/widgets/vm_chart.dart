// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/charts/chart.dart';
import '../../../../../shared/charts/chart_controller.dart';
import '../controller/charts/vm_chart_controller.dart';

class MemoryVMChart extends StatefulWidget {
  const MemoryVMChart(this.chart, {super.key});

  final VMChartController chart;

  @override
  MemoryVMChartState createState() => MemoryVMChartState();
}

class MemoryVMChartState extends State<MemoryVMChart> with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    cancelListeners();
    addAutoDisposeListener(widget.chart.memoryTimeline.sampleAdded);
  }

  @override
  void didUpdateWidget(covariant MemoryVMChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart == widget.chart) return;
    _init();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chart.timestamps.isNotEmpty) {
      return SizedBox(
        height: defaultChartHeight,
        child: Chart(widget.chart),
      );
    }

    return const SizedBox(width: denseSpacing);
  }
}
