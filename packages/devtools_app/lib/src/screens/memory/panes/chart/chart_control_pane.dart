// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
import '../../primitives/ui.dart';
import 'chart_pane_controller.dart';
import 'interval_dropdown.dart';

class ChartControlPane extends StatefulWidget {
  const ChartControlPane({Key? key, required this.chartController})
      : super(key: key);
  final MemoryChartPaneController chartController;

  @override
  State<ChartControlPane> createState() => _ChartControlPaneState();
}

@visibleForTesting
class ChartPaneTooltips {
  static const String pauseTooltip =
      'Pause the chart and auto-collection of snapshots\n'
      'in case of aggressive memory consumption\n'
      '(if enabled in settings)';
  static const String resumeTooltip = 'Resume recording memory statistics';
}

class _ChartControlPaneState extends State<ChartControlPane>
    with
        ProvidedControllerMixin<MemoryController, ChartControlPane>,
        AutoDisposeMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  void _onPause() {
    ga.select(analytics_constants.memory, analytics_constants.pause);
    controller.pauseLiveFeed();
  }

  void _onResume() {
    ga.select(analytics_constants.memory, analytics_constants.resume);
    controller.resumeLiveFeed();
  }

  void _clearTimeline() {
    ga.select(analytics_constants.memory, analytics_constants.clear);

    controller.memoryTimeline.reset();

    // Remove history of all plotted data in all charts.
    widget.chartController.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: controller.paused,
              builder: (context, paused, _) {
                return PauseResumeButtonGroup(
                  paused: paused,
                  onPause: _onPause,
                  onResume: _onResume,
                  pauseTooltip: ChartPaneTooltips.pauseTooltip,
                  resumeTooltip: ChartPaneTooltips.resumeTooltip,
                );
              },
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              onPressed: controller.memorySource == MemoryController.liveFeed
                  ? _clearTimeline
                  : null,
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
              tooltip: 'Clear memory chart.',
            ),
          ],
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.legendVisibleNotifier,
          builder: (_, legendVisible, __) => IconLabelButton(
            onPressed: () {
              controller.toggleLegendVisibility();
              if (legendVisible) {
                ga.select(
                  analytics_constants.memory,
                  analytics_constants.MemoryEvent.chartLegend,
                );
              }
            },
            icon: legendVisible ? Icons.close : Icons.storage,
            label: 'Legend',
            tooltip: 'Show chart legend',
            minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
          ),
        ),
        const SizedBox(height: denseSpacing),
        IntervalDropdown(chartController: widget.chartController),
      ],
    );
  }
}
