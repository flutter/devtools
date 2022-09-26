// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';
import '../../primitives/ui.dart';
import '../chart/chart_pane_controller.dart';

class PrimaryControls extends StatelessWidget {
  const PrimaryControls({
    Key? key,
    required this.chartController,
    required this.controller,
  }) : super(key: key);

  final MemoryChartPaneController chartController;
  final MemoryController controller;

  void _clearTimeline() {
    ga.select(analytics_constants.memory, analytics_constants.clear);

    controller.memoryTimeline.reset();

    // Clear any current Allocation Profile collected.
    controller.monitorAllocations = [];
    controller.monitorTimestamp = null;
    controller.lastMonitorTimestamp.value = null;
    controller.trackAllocations.clear();
    controller.allocationSamples.clear();

    // Clear all analysis and snapshots collected too.
    controller.clearAllSnapshots();
    controller.classRoot = null;
    controller.topNode = null;
    controller.selectedSnapshotTimestamp = null;
    controller.selectedLeaf = null;

    // Remove history of all plotted data in all charts.
    chartController.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ChartButton(),
        const SizedBox(width: defaultSpacing),
        ClearButton(
          onPressed: controller.memorySource == MemoryController.liveFeed
              ? _clearTimeline
              : null,
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
          tooltip: 'Clear all data on the memory screen.',
        ),
      ],
    );
  }
}

class _ChartButton extends StatelessWidget {
  const _ChartButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: preferences.memory.showChart,
      builder: (_, showChart, __) => IconLabelButton(
        key: key,
        tooltip: showChart ? 'Hide chart' : 'Show chart',
        icon: showChart ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
        label: 'Chart',
        minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        onPressed: () => preferences.memory.showChart.value =
            !preferences.memory.showChart.value,
      ),
    );
  }
}
