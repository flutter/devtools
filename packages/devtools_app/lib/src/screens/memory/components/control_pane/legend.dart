// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/notifications.dart';
import '../../../../shared/theme.dart';
import '../../memory_android_chart.dart' as android;
import '../../memory_charts.dart';
import '../../memory_controller.dart';
import '../../memory_events_pane.dart' as events;
import '../../memory_vm_chart.dart' as vm;
import '../../primitives/painting.dart';
import '../../area_controls/constants.dart';
import '../../area_controls/controls_widgets.dart';
import 'memory_config.dart';

class LegendRow extends StatelessWidget {
  const LegendRow(
      {Key? key,
      required this.chartControllers,
      required this.entry1,
      this.entry2})
      : super(key: key);

  final ChartControllers chartControllers;
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

Map<String, Map<String, Object?>> vmLegend(
    vm.VMChartController vmChartController) {
  final result = <String, Map<String, Object?>>{};

  final traces = vmChartController.traces;
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

Map<String, Map<String, Object?>> androidLegend(
    android.AndroidChartController androidChartController) {
  final result = <String, Map<String, Object?>>{};

  final traces = androidChartController.traces;
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
