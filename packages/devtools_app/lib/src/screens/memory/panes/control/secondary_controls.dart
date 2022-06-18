// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../config_specific/logger/logger.dart';
import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/notifications.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
import 'constants.dart';
import 'legend.dart';
import 'settings_dialog.dart';
import 'source_dropdown.dart';

/// Controls related to the entire memory screen.
class SecondaryControls extends StatefulWidget {
  const SecondaryControls({
    Key? key,
    required this.chartControllers,
  }) : super(key: key);

  final ChartControllers chartControllers;

  @override
  State<SecondaryControls> createState() => _SecondaryControlsState();
}

class _SecondaryControlsState extends State<SecondaryControls>
    with
        ProvidedControllerMixin<MemoryController, SecondaryControls>,
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
        if (controller.isLegendVisible) {
          // Recompute the legend with the new traces now visible.
          _hideLegend();
          _showLegend(context);
        }
      });
    });
  }

  void _showLegend(BuildContext context) {
    final box = legendKey.currentContext!.findRenderObject() as RenderBox;

    final colorScheme = Theme.of(context).colorScheme;
    final legendHeading = colorScheme.hoverTextStyle;

    // Global position.
    final position = box.localToGlobal(Offset.zero);

    final legendRows = <Widget>[];

    final events = eventLegend(colorScheme.isLight);
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
          chartControllers: widget.chartControllers,
        ),
      );
    }

    final vms = vmLegend(widget.chartControllers.vm);
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
          chartControllers: widget.chartControllers,
        ),
      );
    }

    if (controller.isAndroidChartVisibleNotifier.value) {
      final androids = androidLegend(widget.chartControllers.android);
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
            chartControllers: widget.chartControllers,
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

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    controller.memorySourcePrefix = mediaWidth > verboseDropDownMinimumWidth
        ? memorySourceMenuItemPrefix
        : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MemorySourceDropdown(),
        const SizedBox(width: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.advancedSettingsEnabled,
          builder: (context, paused, _) {
            return controller.isAdvancedSettingsVisible
                ? Row(
                    children: [
                      IconLabelButton(
                        onPressed: controller.isGcing ? null : _gc,
                        icon: Icons.delete,
                        label: 'GC',
                        minScreenWidthForTextBeforeScaling:
                            primaryControlsMinVerboseWidth,
                      ),
                      const SizedBox(width: denseSpacing),
                    ],
                  )
                : const SizedBox();
          },
        ),
        ExportButton(
          onPressed: controller.offline.value ? null : _exportToFile,
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          key: legendKey,
          onPressed: controller.toggleLegendVisibility,
          icon: _legendOverlayEntry == null ? Icons.storage : Icons.close,
          label: 'Legend',
          tooltip: 'Legend',
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: _openSettingsDialog,
        ),
      ],
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => MemorySettingsDialog(controller),
    );
  }

  void _exportToFile() {
    final outputPath = controller.memoryLog.exportMemory();
    final notificationsState = Notifications.of(context);
    if (notificationsState != null) {
      notificationsState.push(
        'Successfully exported file ${outputPath.last} to ${outputPath.first} directory',
      );
    }
  }

  Future<void> _gc() async {
    try {
      ga.select(analytics_constants.memory, analytics_constants.gc);

      controller.memoryTimeline.addGCEvent();

      await controller.gc();
    } catch (e) {
      // TODO(terry): Show toast?
      log('Unable to GC ${e.toString()}', LogLevel.error);
    }
  }
}
