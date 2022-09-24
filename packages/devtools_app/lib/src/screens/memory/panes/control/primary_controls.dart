// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
import '../../primitives/ui.dart';
import '../chart/chart_pane_controller.dart';
import 'chart_button.dart';
import 'interval_dropdown.dart';

class PrimaryControls extends StatefulWidget {
  const PrimaryControls({
    Key? key,
    required this.chartController,
  }) : super(key: key);

  final MemoryChartPaneController chartController;

  @override
  State<PrimaryControls> createState() => _PrimaryControlsState();
}

class _PrimaryControlsState extends State<PrimaryControls>
    with ProvidedControllerMixin<MemoryController, PrimaryControls> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

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
    widget.chartController.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChartButton(),
        const SizedBox(width: defaultSpacing),
        ClearButton(
          // TODO(terry): Button needs to be Delete for offline data.
          onPressed: controller.memorySource == MemoryController.liveFeed
              ? _clearTimeline
              : null,
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: defaultSpacing),
        IntervalDropdown(chartController: widget.chartController),
      ],
    );
  }
}
