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

class _ChartControlPaneState extends State<ChartControlPane>
    with
        ProvidedControllerMixin<MemoryController, ChartControlPane>,
        AutoDisposeMixin {
  OverlayEntry? _legendOverlayEntry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    // TODO(polinach): do we need these listeners?
    // https://github.com/flutter/devtools/pull/4136#discussion_r881773861
    addAutoDisposeListener(controller.legendVisibleNotifier, () {
      setState(() {
        if (controller.isLegendVisible) {
          ga.select(
            analytics_constants.memory,
            analytics_constants.memoryLegend,
          );

          _showLegend(context);
        } else {
          _hideLegend();
        }
      });
    });

    addAutoDisposeListener(controller.isAndroidChartVisibleNotifier, () {
      setState(() {
        if (controller.isAndroidChartVisibleNotifier.value) {
          ga.select(
            analytics_constants.memory,
            analytics_constants.androidChart,
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      // Move down!!!!!!
      valueListenable: controller.paused,
      builder: (context, paused, _) {
        return Column(
          children: [
            PauseButton(
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
              onPressed: paused ? null : _onPause,
            ),
            const SizedBox(height: denseSpacing),
            ResumeButton(
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
              onPressed: paused ? _onResume : null,
            ),
            const SizedBox(height: defaultSpacing),
            IntervalDropdown(chartController: widget.chartController),
            const SizedBox(width: denseSpacing),
            IconLabelButton(
              key: legendKey,
              onPressed: controller.toggleLegendVisibility,
              icon: _legendOverlayEntry == null ? Icons.storage : Icons.close,
              label: 'Legend',
              tooltip: 'Legend',
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
            ),
          ],
        );
      },
    );
  }

  void _showLegend(BuildContext context) {
    final box = legendKey.currentContext!.findRenderObject() as RenderBox;

    final colorScheme = Theme.of(context).colorScheme;
    final legendHeading = colorScheme.hoverTextStyle;

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

    final OverlayState overlayState = Overlay.of(context)!;
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
