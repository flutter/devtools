// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';
import 'constants.dart';
import 'interval_dropdown.dart';

class PrimaryControls extends StatefulWidget {
  const PrimaryControls({
    Key? key,
    required this.chartControllers,
  }) : super(key: key);

  final ChartControllers chartControllers;

  @override
  State<PrimaryControls> createState() => _PrimaryControlsState();
}

class _PrimaryControlsState extends State<PrimaryControls>
    with MemoryControllerMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    initMemoryController();
  }

  void _onPause() {
    ga.select(analytics_constants.memory, analytics_constants.pause);
    memoryController.pauseLiveFeed();
  }

  void _onResume() {
    ga.select(analytics_constants.memory, analytics_constants.resume);
    memoryController.resumeLiveFeed();
  }

  void _clearTimeline() {
    ga.select(analytics_constants.memory, analytics_constants.clear);

    memoryController.memoryTimeline.reset();

    // Clear any current Allocation Profile collected.
    memoryController.monitorAllocations = [];
    memoryController.monitorTimestamp = null;
    memoryController.lastMonitorTimestamp.value = null;
    memoryController.trackAllocations.clear();
    memoryController.allocationSamples.clear();

    // Clear all analysis and snapshots collected too.
    memoryController.clearAllSnapshots();
    memoryController.classRoot = null;
    memoryController.topNode = null;
    memoryController.selectedSnapshotTimestamp = null;
    memoryController.selectedLeaf = null;

    // Remove history of all plotted data in all charts.
    widget.chartControllers.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: memoryController.paused,
      builder: (context, paused, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PauseButton(
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
              onPressed: paused ? null : _onPause,
            ),
            const SizedBox(width: denseSpacing),
            ResumeButton(
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
              onPressed: paused ? _onResume : null,
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              // TODO(terry): Button needs to be Delete for offline data.
              onPressed:
                  memoryController.memorySource == MemoryController.liveFeed
                      ? _clearTimeline
                      : null,
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
            ),
            const SizedBox(width: defaultSpacing),
            IntervalDropdown(chartControllers: widget.chartControllers),
          ],
        );
      },
    );
  }
}
