// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/primitives/auto_dispose.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
import '../../shared/primitives/simple_elements.dart';
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
    ga.select(gac.memory, gac.pause);
    controller.pauseLiveFeed();
  }

  void _onResume() {
    ga.select(gac.memory, gac.resume);
    controller.resumeLiveFeed();
  }

  void _clearTimeline() {
    ga.select(gac.memory, gac.clear);

    controller.memoryTimeline.reset();

    // Remove history of all plotted data in all charts.
    widget.chartController.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
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
            _LegendButton(chartController: widget.chartController),
          ],
        ),
        const SizedBox(height: denseSpacing),
        IntervalDropdown(chartController: widget.chartController),
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
      valueListenable: chartController.legendVisibleNotifier,
      builder: (_, legendVisible, __) => DevToolsButton(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Memory chart shows trace\n'
              'of application memory usage.'),
          MoreInfoLink(
            url: DocLinks.chart.value,
            gaScreenName: '',
            gaSelectedItemDescription:
                gac.topicDocumentationLink(_documentationTopic),
          ),
        ],
      ),
    );
  }
}
