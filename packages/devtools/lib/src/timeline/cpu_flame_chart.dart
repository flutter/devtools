// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:math' as math;
import '../ui/drag_scroll.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import 'cpu_profile_protocol.dart';
import 'flame_chart.dart';

final StreamController<CpuFlameChartItem> _selectedCpuFlameChartItemController =
    StreamController<CpuFlameChartItem>.broadcast();

Stream<CpuFlameChartItem> get onSelectedCpuFlameChartItem =>
    _selectedCpuFlameChartItemController.stream;

final DragScroll _dragScroll = DragScroll();

const colorPalette = [
  Color(0xFFFF5722),
  Color(0xFFFF6D00),
  Color(0xFFFFAB00),
  Color(0xFFFFD600),
  Color(0xFFFFEA00),
];

class CpuFlameChart extends FlameChart<CpuProfileData> {
  CpuFlameChart()
      : super(
          onSelectedFlameChartItem: onSelectedCpuFlameChartItem,
          dragScroll: _dragScroll,
          classes: 'cpu-flame-chart ui-details-section',
          flameChartInset: 4,
        );

  static const samplePadding = 1;

  int _colorOffset = 0;

  // TODO(kenzie): maybe colors should be based on CPU consumption or on
  // categories (Widget, Render, Layer, User code, etc.)
  Color nextColor() {
    final color = colorPalette[_colorOffset % colorPalette.length];
    _colorOffset++;
    return color;
  }

  @override
  void reset() {
    super.reset();
    _colorOffset = 0;
  }

  // TODO(kenzie): rewrite this render method to draw to canvas.
  @override
  void render() {
    final CpuProfileData cpuProfileData = data;
    final totalWidth = element.clientWidth - 2 * flameChartInset;

    final Map<String, double> stackFrameLefts = {};

    double calculateLeftForStackFrame(CpuStackFrame stackFrame) {
      double left;
      if (stackFrame.parent == null) {
        left = flameChartInset.toDouble();
      } else {
        final stackFrameIndex = stackFrame.index;
        if (stackFrameIndex == 0) {
          // This is the first child of parent. [left] should equal the left
          // value of [stackFrame]'s parent.
          left = stackFrameLefts[stackFrame.parent.id];
        } else {
          assert(stackFrameIndex != -1);
          // [stackFrame] is not the first child of its parent. [left] should
          // equal the right value of its previous sibling.
          final previous = stackFrame.parent.children[stackFrameIndex - 1];
          left = stackFrameLefts[previous.id] +
              (totalWidth * previous.cpuConsumptionRatio);
        }
      }
      stackFrameLefts[stackFrame.id] = left;
      return left;
    }

    void drawSubtree(CpuStackFrame stackFrame, int row) {
      final double width =
          totalWidth * stackFrame.cpuConsumptionRatio - samplePadding;

      final item = CpuFlameChartItem(
        stackFrame,
        calculateLeftForStackFrame(stackFrame),
        width,
        row * FlameChart.rowHeight + FlameChart.padding,
        nextColor(),
        Colors.black,
        Colors.black,
      );
      addItemToFlameChart(item, this);

      for (CpuStackFrame child in stackFrame.children) {
        drawSubtree(
          child,
          row + 1,
        );
      }
    }

    drawSubtree(cpuProfileData.cpuProfileRoot, 0);
  }

  @override
  void updateChartForZoom() {
    super.updateChartForZoom();
    element.scrollLeft = math.max(0, floatingPointScrollLeft.round());
  }
}

class CpuFlameChartItem extends FlameChartItem {
  CpuFlameChartItem(
    this.stackFrame,
    num startingLeft,
    num startingWidth,
    num top,
    Color backgroundColor,
    Color defaultTextColor,
    Color selectedTextColor,
  ) : super(
          startingLeft: startingLeft,
          startingWidth: startingWidth,
          top: top,
          backgroundColor: backgroundColor,
          defaultTextColor: defaultTextColor,
          selectedTextColor: selectedTextColor,
        );

  final CpuStackFrame stackFrame;

  @override
  void setText() {
    element.title = stackFrame.toString();

    if (stackFrame.parent == null) {
      itemLabel.text = stackFrame.toString();
    } else {
      itemLabel.text = stackFrame.name;
    }
  }

  @override
  void setOnClick() {
    element.onClick.listen((e) {
      // Prevent clicks when the chart was being dragged.
      if (!_dragScroll.wasDragged) {
        _selectedCpuFlameChartItemController.add(this);
      }
    });
  }
}

class CpuFunction {
  CpuFunction(this.name, this.percentCpuConsumption, this.numSamples);

  final String name;
  final double percentCpuConsumption;
  final int numSamples;

  @override
  String toString() => '$name ($numSamples samples, $percentCpuConsumption%)';
}
