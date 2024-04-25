// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/ui/colors.dart';
import '../../../shared/primitives/painting.dart';
import '../controller/charts/android_chart_controller.dart';
import '../controller/chart_pane_controller.dart';
import '../controller/charts/vm_chart_controller.dart';
import '../data/charts.dart';
import 'charts/events_chart.dart';

final _legendWidth = scaleByFontFactor(200.0);
final _legendTextWidth = scaleByFontFactor(55.0);
final _legendHeight1Chart = scaleByFontFactor(200.0);
final _legendHeight2Charts = scaleByFontFactor(323.0);

/// Padding for each title in the legend.
const _legendTitlePadding = EdgeInsets.only(left: 5, bottom: 4);

class MemoryChartLegend extends StatelessWidget {
  const MemoryChartLegend({
    super.key,
    required this.isAndroidVisible,
    required this.chartController,
  });

  final bool isAndroidVisible;
  final MemoryChartPaneController chartController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final legendRows = <Widget>[];

    final events = eventLegendContent(colorScheme.isLight);
    legendRows.add(
      Container(
        padding: _legendTitlePadding,
        child: Text('Events Legend', style: theme.legendTextStyle),
      ),
    );

    final iterator = events.entries.iterator;
    while (iterator.moveNext()) {
      final leftEntry = iterator.current;
      final rightEntry = iterator.moveNext() ? iterator.current : null;
      legendRows.add(
        LegendRow(
          entry1: leftEntry,
          entry2: rightEntry,
        ),
      );
    }

    final vms = vmLegendContent(chartController.vm);
    legendRows.add(
      Container(
        padding: _legendTitlePadding,
        child: Text('Memory Legend', style: theme.legendTextStyle),
      ),
    );

    for (final entry in vms.entries) {
      legendRows.add(
        LegendRow(
          entry1: entry,
        ),
      );
    }

    if (isAndroidVisible) {
      final androids = androidLegendContent(chartController.android);
      legendRows.add(
        Container(
          padding: _legendTitlePadding,
          child: Text('Android Legend', style: theme.legendTextStyle),
        ),
      );

      for (final entry in androids.entries) {
        legendRows.add(
          LegendRow(
            entry1: entry,
          ),
        );
      }
    }

    return Container(
      width: _legendWidth,
      // The height is specified here,
      // because [legendRows] are designed to take all available space.
      height: isAndroidVisible ? _legendHeight2Charts : _legendHeight1Chart,
      padding: const EdgeInsets.fromLTRB(0, densePadding, densePadding, 0),
      decoration: BoxDecoration(
        color: colorScheme.defaultBackgroundColor,
        border: Border.all(color: theme.focusColor),
        borderRadius: defaultBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: legendRows,
      ),
    );
  }
}

class LegendRow extends StatelessWidget {
  const LegendRow({
    super.key,
    required this.entry1,
    this.entry2,
  });

  final MapEntry<String, Map<String, Object?>> entry1;
  final MapEntry<String, Map<String, Object?>>? entry2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final legendEntry = theme.legendTextStyle;

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
            width: _legendTextWidth + leftEdge,
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
    final entry2Local = entry2;
    if (entry2Local != null) {
      rowChildren.addAll(
        legendPart(entry2Local.key, legendSymbol(entry2Local.value), 20.0),
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.only(left: 10, bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rowChildren,
        ),
      ),
    );
  }
}

Map<String, Map<String, Object?>> eventLegendContent(bool isLight) => {
      manualSnapshotLegendName: traceRender(
        image: snapshotManualLegend,
      ),
      autoSnapshotLegendName: traceRender(
        image: snapshotAutoLegend,
      ),
      monitorLegendName: traceRender(
        image: monitorLegend,
      ),
      resetLegendName: traceRender(
        image: isLight ? resetLightLegend : resetDarkLegend,
      ),
      vmGCLegendName: traceRender(
        image: gcVMLegend,
      ),
      manualGCLegendName: traceRender(
        image: gcManualLegend,
      ),
      // TODO: why do we need both a singular and plural legend entry for event?
      eventLegendName: traceRender(
        image: eventLegendAsset(1),
      ),
      eventsLegendName: traceRender(
        image: eventLegendAsset(2),
      ),
    };

Map<String, Map<String, Object?>> vmLegendContent(
  VMChartController vmChartController,
) {
  final traces = vmChartController.traces;

  return <String, Map<String, Object?>>{
    // RSS trace
    rssDisplay: traceRender(
      color: traces[VmTraceName.rSS.index].characteristics.color,
      dashed: true,
    ),

    // Allocated trace
    allocatedDisplay: traceRender(
      color: traces[VmTraceName.capacity.index].characteristics.color,
      dashed: true,
    ),

    // Used trace
    usedDisplay: traceRender(
      color: traces[VmTraceName.used.index].characteristics.color,
    ),

    // External trace
    externalDisplay: traceRender(
      color: traces[VmTraceName.external.index].characteristics.color,
    ),

    // Raster layer trace
    layerDisplay: traceRender(
      color: traces[VmTraceName.rasterLayer.index].characteristics.color,
      dashed: true,
    ),

    // Raster picture trace
    pictureDisplay: traceRender(
      color: traces[VmTraceName.rasterPicture.index].characteristics.color,
      dashed: true,
    ),
  };
}

Map<String, Map<String, Object?>> androidLegendContent(
  AndroidChartController androidChartController,
) {
  final traces = androidChartController.traces;

  return <String, Map<String, Object?>>{
    // Total trace
    androidTotalDisplay: traceRender(
      color: traces[AndroidTraceName.total.index].characteristics.color,
      dashed: true,
    ),

    // Other trace
    androidOtherDisplay: traceRender(
      color: traces[AndroidTraceName.other.index].characteristics.color,
    ),

    // Native heap trace
    androidNativeDisplay: traceRender(
      color: traces[AndroidTraceName.nativeHeap.index].characteristics.color,
    ),

    // Graphics trace
    androidGraphicsDisplay: traceRender(
      color: traces[AndroidTraceName.graphics.index].characteristics.color,
    ),

    // Code trace
    androidCodeDisplay: traceRender(
      color: traces[AndroidTraceName.code.index].characteristics.color,
    ),

    // Java heap trace
    androidJavaDisplay: traceRender(
      color: traces[AndroidTraceName.javaHeap.index].characteristics.color,
    ),

    // Stack trace
    androidStackDisplay: traceRender(
      color: traces[AndroidTraceName.stack.index].characteristics.color,
    ),
  };
}
