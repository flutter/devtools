// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/charts/chart.dart';
import '../../../../shared/primitives/memory_timeline.dart';
import '../../controller/charts/vm_chart_controller.dart';

class MemoryVMChart extends StatefulWidget {
  const MemoryVMChart(this.chart, {super.key});

  final VMChartController chart;

  @override
  MemoryVMChartState createState() => MemoryVMChartState();
}

class MemoryVMChartState extends State<MemoryVMChart> with AutoDisposeMixin {
  /// Controller attached to the chart.
  VMChartController get _chartController => widget.chart;

  MemoryTimeline get _memoryTimeline => widget.chart.memoryTimeline;

  @override
  void initState() {
    super.initState();

    _init();
  }

  void _init() {
    cancelListeners();

    widget.chart.setupTraces();
    _chartController.setupData();

    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      if (_memoryTimeline.sampleAddedNotifier.value != null) {
        setState(() {
          _processHeapSample(_memoryTimeline.sampleAddedNotifier.value!);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant MemoryVMChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart == widget.chart) return;
    _init();
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController.timestamps.isNotEmpty) {
      return SizedBox(
        height: defaultChartHeight,
        child: Chart(_chartController),
      );
    }

    return const SizedBox(width: denseSpacing);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (widget.chart.paused.value) return;
    _chartController.addSample(sample);
  }
}
