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
import '../../shared/constants.dart';
import 'chart_pane_controller.dart';
import 'interval_dropdown.dart';
import 'legend.dart';

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
  OverlayEntry? _legendOverlayEntry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    addAutoDisposeListener(controller.legendVisibleNotifier, () {
      setState(() {
        if (controller.isLegendVisible) {
          ga.select(
            analytics_constants.memory,
            analytics_constants.MemoryEvent.chartLegend,
          );
          _showLegend(context);
        } else {
          _hideLegend();
        }
      });
    });

    // Refresh legend if android chary visibility changed.
    addAutoDisposeListener(controller.isAndroidChartVisibleNotifier, () {
      setState(() {
        if (controller.isLegendVisible) {
          // Recompute the legend with the new traces now visible.
          _hideLegend();
          _showLegend(context);
        }
      });
    });
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
        IconLabelButton(
          key: legendKey,
          onPressed: controller.toggleLegendVisibility,
          icon: _legendOverlayEntry == null ? Icons.storage : Icons.close,
          label: 'Legend',
          tooltip: 'Show chart legend',
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(height: denseSpacing),
        IntervalDropdown(chartController: widget.chartController),
      ],
    );
  }

  void _showLegend(BuildContext context) {
    final box = legendKey.currentContext!.findRenderObject() as RenderBox;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final legendHeading = theme.hoverTextStyle;

    // Global position.
    final position = box.localToGlobal(Offset.zero);

    final legendRows = <Widget>[];

    final events = eventLegendContent(colorScheme.isLight);
    legendRows.add(
      Container(
        padding: legendTitlePadding,
        child: Text('Events Legend', style: legendHeading),
      ),
    );

    var iterator = events.entries.iterator;
    while (iterator.moveNext()) {
      final leftEntry = iterator.current;
      final rightEntry = iterator.moveNext() ? iterator.current : null;
      legendRows.add(
        LegendRow(
          entry1: leftEntry,
          entry2: rightEntry,
          chartController: widget.chartController,
        ),
      );
    }

    final vms = vmLegendContent(widget.chartController.vm);
    legendRows.add(
      Container(
        padding: legendTitlePadding,
        child: Text('Memory Legend', style: legendHeading),
      ),
    );

    iterator = vms.entries.iterator;
    while (iterator.moveNext()) {
      final legendEntry = iterator.current;
      legendRows.add(
        LegendRow(
          entry1: legendEntry,
          chartController: widget.chartController,
        ),
      );
    }

    if (controller.isAndroidChartVisibleNotifier.value) {
      final androids = androidLegendContent(widget.chartController.android);
      legendRows.add(
        Container(
          padding: legendTitlePadding,
          child: Text('Android Legend', style: legendHeading),
        ),
      );

      iterator = androids.entries.iterator;
      while (iterator.moveNext()) {
        final legendEntry = iterator.current;
        legendRows.add(
          LegendRow(
            entry1: legendEntry,
            chartController: widget.chartController,
          ),
        );
      }
    }

    final OverlayState overlayState = Overlay.of(context);
    _legendOverlayEntry ??= OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + box.size.height + legendYOffset,
        left: position.dx - legendWidth + box.size.width - legendXOffset,
        height: controller.isAndroidChartVisibleNotifier.value
            ? legendHeight2Charts
            : legendHeight1Chart,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 5, 5, 8),
          decoration: BoxDecoration(
            color: colorScheme.defaultBackgroundColor,
            border: Border.all(color: Colors.yellow),
            borderRadius: BorderRadius.circular(10.0),
          ),
          width: legendWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendRows,
          ),
        ),
      ),
    );

    overlayState.insert(_legendOverlayEntry!);
  }

  void _hideLegend() {
    _legendOverlayEntry?.remove();
    _legendOverlayEntry = null;
  }
}
