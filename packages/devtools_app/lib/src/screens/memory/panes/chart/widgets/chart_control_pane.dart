// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/primitives/simple_items.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../controller/chart_pane_controller.dart';
import 'interval_dropdown.dart';

class ChartControlPane extends StatefulWidget {
  const ChartControlPane({Key? key, required this.chart}) : super(key: key);
  final MemoryChartPaneController chart;

  @override
  State<ChartControlPane> createState() => _ChartControlPaneState();
}

@visibleForTesting
class ChartPaneTooltips {
  static const String pauseTooltip = 'Pause the chart';
  static const String resumeTooltip = 'Resume the chart';
}

class _ChartControlPaneState extends State<ChartControlPane>
    with AutoDisposeMixin {
  void _onPause() {
    ga.select(gac.memory, gac.pause);
    widget.chart.pauseLiveFeed();
  }

  void _onResume() {
    ga.select(gac.memory, gac.resume);
    widget.chart.resumeLiveFeed();
  }

  void _clearTimeline() {
    ga.select(gac.memory, gac.clear);

    widget.chart.memoryTimeline.reset();

    // Remove history of all plotted data in all charts.
    widget.chart.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: widget.chart.paused,
              builder: (context, paused, _) {
                return PauseResumeButtonGroup(
                  paused: paused,
                  onPause: _onPause,
                  onResume: _onResume,
                  pauseTooltip: ChartPaneTooltips.pauseTooltip,
                  resumeTooltip: ChartPaneTooltips.resumeTooltip,
                  gaScreen: gac.memory,
                  gaSelectionPause: gac.MemoryEvent.pauseChart,
                  gaSelectionResume: gac.MemoryEvent.resumeChart,
                );
              },
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              onPressed: _clearTimeline,
              tooltip: 'Clear memory chart.',
              gaScreen: gac.memory,
              gaSelection: gac.MemoryEvent.clearChart,
              iconOnly: true,
            ),
          ],
        ),
        const SizedBox(height: denseSpacing),
        Row(
          children: [
            _LegendButton(chartController: widget.chart),
          ],
        ),
        const SizedBox(height: denseSpacing),
        IntervalDropdown(chartController: widget.chart),
        const SizedBox(height: denseSpacing),
        const _ChartHelpLink(),
      ],
    );
  }
}

class _LegendButton extends StatelessWidget {
  const _LegendButton({required this.chartController});

  final MemoryChartPaneController chartController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: chartController.isLegendVisible,
      builder: (_, legendVisible, __) => GaDevToolsButton(
        onPressed: chartController.toggleLegendVisibility,
        gaScreen: gac.memory,
        gaSelection: legendVisible
            ? gac.MemoryEvent.hideChartLegend
            : gac.MemoryEvent.showChartLegend,
        icon: legendVisible ? Icons.close : Icons.storage,
        label: 'Legend',
        tooltip: 'Toggle visibility of the chart legend',
        minScreenWidthForTextBeforeScaling: memoryControlsMinVerboseWidth,
      ),
    );
  }
}

class _ChartHelpLink extends StatelessWidget {
  const _ChartHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = gac.MemoryEvent.chartHelp;

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: gac.memory,
      gaSelection: gac.topicDocumentationButton(_documentationTopic),
      dialogTitle: 'Memory Chart Help',
      actions: [
        MoreInfoLink(
          url: DocLinks.chart.value,
          gaScreenName: '',
          gaSelectedItemDescription:
              gac.topicDocumentationLink(_documentationTopic),
        ),
      ],
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'The memory chart shows live and historical\n'
            ' memory usage statistics for your application.',
          ),
        ],
      ),
    );
  }
}
