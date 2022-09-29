// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../../primitives/painting.dart';
import '../../shared/constants.dart';
import 'chart_pane_controller.dart';
import 'memory_android_chart.dart';
import 'memory_charts.dart';
import 'memory_events_pane.dart';
import 'memory_vm_chart.dart';

class LegendRow extends StatelessWidget {
  const LegendRow({
    Key? key,
    required this.chartController,
    required this.entry1,
    this.entry2,
  }) : super(key: key);

  final MemoryChartPaneController chartController;
  final MapEntry<String, Map<String, Object?>> entry1;
  final MapEntry<String, Map<String, Object?>>? entry2;

  @override
  Widget build(BuildContext context) {
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
    final entry2Local = entry2;
    if (entry2Local != null) {
      rowChildren.addAll(
        legendPart(entry2Local.key, legendSymbol(entry2Local.value), 20.0),
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
      eventLegendName: traceRender(
        image: eventLegend,
      ),
      eventsLegendName: traceRender(
        image: eventsLegend,
      )
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
    )
  };
}
