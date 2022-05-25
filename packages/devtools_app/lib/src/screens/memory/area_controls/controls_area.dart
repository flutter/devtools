// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../analytics/analytics.dart' as ga;
import '../../../analytics/constants.dart' as analytics_constants;
import '../../../primitives/auto_dispose_mixin.dart';
import '../../../shared/common_widgets.dart';
import '../../../shared/notifications.dart';
import '../../../shared/theme.dart';
import '../memory_android_chart.dart' as android;
import '../memory_charts.dart';
import '../memory_controller.dart';
import '../memory_events_pane.dart' as events;
import '../memory_vm_chart.dart' as vm;
import '../primitives/painting.dart';
import 'constants.dart';
import 'controls_widgets.dart';
import 'memory_config.dart';

class MemoryControls extends StatefulWidget {
  const MemoryControls({
    Key? key,
    required this.chartControllers,
  }) : super(key: key);

  final ChartControllers chartControllers;

  @override
  State<MemoryControls> createState() => _MemoryControlsState();
}

class _MemoryControlsState extends State<MemoryControls> with AutoDisposeMixin {
  /// Updated when the MemoryController's _androidCollectionEnabled ValueNotifier changes.
  bool _isAndroidCollection = MemoryController.androidADBDefault;
  bool _isAdvancedSettingsEnabled = false;
  OverlayEntry? _legendOverlayEntry;

  bool controllersInitialized = false;
  late MemoryController _controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ChartControls(chartControllers: widget.chartControllers),
        const Spacer(),
        CommonControls(
            isAndroidCollection: _isAndroidCollection,
            isAdvancedSettingsEnabled: _isAdvancedSettingsEnabled)
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);
    if (!controllersInitialized || newController != _controller) {
      controllersInitialized = true;
      _controller = newController;
    }

    addAutoDisposeListener(_controller.androidCollectionEnabled, () {
      _isAndroidCollection = _controller.androidCollectionEnabled.value;
      setState(() {
        if (!_isAndroidCollection && _controller.isAndroidChartVisible) {
          // If we're no longer collecting android stats then hide the
          // chart and disable the Android Memory button.
          _controller.toggleAndroidChartVisibility();
        }
      });
    });

    addAutoDisposeListener(_controller.advancedSettingsEnabled, () {
      _isAdvancedSettingsEnabled = _controller.advancedSettingsEnabled.value;
      setState(() {
        if (!_isAdvancedSettingsEnabled &&
            _controller.isAdvancedSettingsVisible) {
          _controller.toggleAdvancedSettingsVisibility();
        }
      });
    });

    addAutoDisposeListener(_controller.legendVisibleNotifier, () {
      setState(() {
        if (_controller.isLegendVisible) {
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

    addAutoDisposeListener(_controller.androidChartVisibleNotifier, () {
      setState(() {
        if (_controller.androidChartVisibleNotifier.value) {
          ga.select(
            analytics_constants.memory,
            analytics_constants.androidChart,
          );
        }
        if (_controller.isLegendVisible) {
          // Recompute the legend with the new traces now visible.
          _hideLegend();
          _showLegend(context);
        }
      });
    });
  }

  void _exportToFile() {
    final outputPath = _controller.memoryLog.exportMemory();
    final notificationsState = Notifications.of(context);
    if (notificationsState != null) {
      notificationsState.push(
        'Successfully exported file ${outputPath.last} to ${outputPath.first} directory',
      );
    }
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => MemoryConfigurationsDialog(_controller),
    );
  }

  /// Padding for each title in the legend.
  static const _legendTitlePadding = EdgeInsets.fromLTRB(5, 0, 0, 4);

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
        padding: _legendTitlePadding,
        child: Text('Events Legend', style: legendHeading),
      ),
    );

    var iterator = events.entries.iterator;
    while (iterator.moveNext()) {
      final leftEntry = iterator.current;
      final rightEntry = iterator.moveNext() ? iterator.current : null;
      legendRows.add(legendRow(entry1: leftEntry, entry2: rightEntry));
    }

    final vms = vmLegend();
    legendRows.add(
      Container(
        padding: _legendTitlePadding,
        child: Text('Memory Legend', style: legendHeading),
      ),
    );

    iterator = vms.entries.iterator;
    while (iterator.moveNext()) {
      final legendEntry = iterator.current;
      legendRows.add(legendRow(entry1: legendEntry));
    }

    if (_controller.isAndroidChartVisible) {
      final androids = androidLegend();
      legendRows.add(
        Container(
          padding: _legendTitlePadding,
          child: Text('Android Legend', style: legendHeading),
        ),
      );

      iterator = androids.entries.iterator;
      while (iterator.moveNext()) {
        final legendEntry = iterator.current;
        legendRows.add(legendRow(entry1: legendEntry));
      }
    }

    final OverlayState overlayState = Overlay.of(context)!;
    _legendOverlayEntry ??= OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + box.size.height + legendYOffset,
        left: position.dx - legendWidth + box.size.width - legendXOffset,
        height: _controller.isAndroidChartVisible
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

  Map<String, Map<String, Object?>> eventLegend(bool isLight) {
    final result = <String, Map<String, Object?>>{};

    result[events.manualSnapshotLegendName] = traceRender(
      image: events.snapshotManualLegend,
    );
    result[events.autoSnapshotLegendName] = traceRender(
      image: events.snapshotAutoLegend,
    );
    result[events.monitorLegendName] = traceRender(image: events.monitorLegend);
    result[events.resetLegendName] = traceRender(
      image: isLight ? events.resetLightLegend : events.resetDarkLegend,
    );
    result[events.vmGCLegendName] = traceRender(image: events.gcVMLegend);
    result[events.manualGCLegendName] = traceRender(
      image: events.gcManualLegend,
    );
    result[events.eventLegendName] = traceRender(image: events.eventLegend);
    result[events.eventsLegendName] = traceRender(image: events.eventsLegend);

    return result;
  }

  Map<String, Map<String, Object?>> vmLegend() {
    final result = <String, Map<String, Object?>>{};

    final traces = widget.chartControllers.vm.traces;
    // RSS trace
    result[rssDisplay] = traceRender(
      color: traces[vm.TraceName.rSS.index].characteristics.color,
      dashed: true,
    );

    // Allocated trace
    result[allocatedDisplay] = traceRender(
      color: traces[vm.TraceName.capacity.index].characteristics.color,
      dashed: true,
    );

    // Used trace
    result[usedDisplay] = traceRender(
      color: traces[vm.TraceName.used.index].characteristics.color,
    );

    // External trace
    result[externalDisplay] = traceRender(
      color: traces[vm.TraceName.external.index].characteristics.color,
    );

    // Raster layer trace
    result[layerDisplay] = traceRender(
      color: traces[vm.TraceName.rasterLayer.index].characteristics.color,
      dashed: true,
    );

    // Raster picture trace
    result[pictureDisplay] = traceRender(
      color: traces[vm.TraceName.rasterPicture.index].characteristics.color,
      dashed: true,
    );

    return result;
  }

  Map<String, Map<String, Object?>> androidLegend() {
    final result = <String, Map<String, Object?>>{};

    final traces = widget.chartControllers.android.traces;
    // Total trace
    result[androidTotalDisplay] = traceRender(
      color: traces[android.TraceName.total.index].characteristics.color,
      dashed: true,
    );

    // Other trace
    result[androidOtherDisplay] = traceRender(
      color: traces[android.TraceName.other.index].characteristics.color,
    );

    // Native heap trace
    result[androidNativeDisplay] = traceRender(
      color: traces[android.TraceName.nativeHeap.index].characteristics.color,
    );

    // Graphics trace
    result[androidGraphicsDisplay] = traceRender(
      color: traces[android.TraceName.graphics.index].characteristics.color,
    );

    // Code trace
    result[androidCodeDisplay] = traceRender(
      color: traces[android.TraceName.code.index].characteristics.color,
    );

    // Java heap trace
    result[androidJavaDisplay] = traceRender(
      color: traces[android.TraceName.javaHeap.index].characteristics.color,
    );

    // Stack trace
    result[androidStackDisplay] = traceRender(
      color: traces[android.TraceName.stack.index].characteristics.color,
    );

    return result;
  }

  Widget legendRow({
    required MapEntry<String, Map<String, Object?>> entry1,
    MapEntry<String, Map<String, Object?>>? entry2,
  }) {
    final legendEntry = Theme.of(context).colorScheme.legendTextStyle;

    List<Widget> legendPart(
      String name,
      Widget widget, [
      double leftEdge = 5.0,
    ]) {
      final rightSide = <Widget>[];
      rightSide.addAll([
        Expanded(
          child: Container(
            padding: EdgeInsets.fromLTRB(leftEdge, 0, 0, 2),
            width: legendTextWidth + leftEdge,
            child: Text(name, style: legendEntry),
          ),
        ),
        const PaddedDivider(
          padding: EdgeInsets.only(left: denseRowSpacing),
        ),
        widget,
      ]);

      return rightSide;
    }

    Widget legendSymbol(Map<String, Object?> dataToDisplay) {
      final image = dataToDisplay.containsKey(renderImage)
          ? dataToDisplay[renderImage] as String?
          : null;
      final color = dataToDisplay.containsKey(renderLine)
          ? dataToDisplay[renderLine] as Color?
          : null;
      final dashedLine = dataToDisplay.containsKey(renderDashed)
          ? dataToDisplay[renderDashed]
          : false;

      Widget traceColor;
      if (color != null) {
        if (dashedLine as bool) {
          traceColor = createDashWidget(color);
        } else {
          traceColor = createSolidLine(color);
        }
      } else {
        traceColor =
            image == null ? const SizedBox() : Image(image: AssetImage(image));
      }

      return traceColor;
    }

    final rowChildren = <Widget>[];

    rowChildren.addAll(legendPart(entry1.key, legendSymbol(entry1.value)));
    if (entry2 != null) {
      rowChildren.addAll(
        legendPart(entry2.key, legendSymbol(entry2.value), 20.0),
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 0, 0, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rowChildren,
        ),
      ),
    );
  }
}
