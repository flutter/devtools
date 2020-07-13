// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../charts/flame_chart.dart';
import '../ui/colors.dart';
import '../utils.dart';
import 'cpu_profile_model.dart';

class CpuProfileFlameChart extends FlameChart<CpuProfileData, CpuStackFrame> {
  CpuProfileFlameChart(
    CpuProfileData data, {
    @required double width,
    @required double height,
    @required ValueListenable<CpuStackFrame> selectionNotifier,
    @required Function(CpuStackFrame stackFrame) onSelected,
  }) : super(
          data,
          time: data.profileMetaData.time,
          containerWidth: width,
          containerHeight: height,
          startInset: sideInsetSmall,
          endInset: sideInsetSmall,
          selectionNotifier: selectionNotifier,
          onSelected: onSelected,
        );

  @override
  _CpuProfileFlameChartState createState() => _CpuProfileFlameChartState();
}

class _CpuProfileFlameChartState
    extends FlameChartState<CpuProfileFlameChart, CpuStackFrame> {
  static const stackFramePadding = 1;

  int _colorOffset = 0;

  final Map<String, double> stackFrameLefts = {};

  @override
  void initFlameChartElements() {
    super.initFlameChartElements();
    expandRows(widget.data.cpuProfileRoot.depth +
        rowOffsetForTopPadding +
        FlameChart.rowOffsetForBottomPadding);

    void createChartNodes(CpuStackFrame stackFrame, int row) {
      final double width =
          widget.startingContentWidth * stackFrame.totalTimeRatio -
              stackFramePadding;
      final left = leftForStackFrame(stackFrame);
      final backgroundColor = _colorForStackFrame(stackFrame);

      final node = FlameChartNode<CpuStackFrame>(
        key: Key('${stackFrame.id}'),
        text: stackFrame.name,
        tooltip: '${stackFrame.name} - ${msText(stackFrame.totalTime)}',
        rect: Rect.fromLTWH(left, flameChartNodeTop, width, rowHeight),
        backgroundColor: backgroundColor,
        textColor: Colors.black,
        data: stackFrame,
        onSelected: (dynamic frame) => widget.onSelected(frame),
      )..sectionIndex = 0;

      rows[row].addNode(node);

      for (CpuStackFrame child in stackFrame.children) {
        createChartNodes(child, row + 1);
      }
    }

    createChartNodes(widget.data.cpuProfileRoot, rowOffsetForTopPadding);
  }

  double leftForStackFrame(CpuStackFrame stackFrame) {
    final CpuStackFrame parent = stackFrame.parent;
    double left;
    if (parent == null) {
      left = widget.startInset;
    } else {
      final stackFrameIndex = stackFrame.index;
      if (stackFrameIndex == 0) {
        // This is the first child of parent. [left] should equal the left
        // value of [stackFrame]'s parent.
        left = stackFrameLefts[parent.id];
      } else {
        assert(stackFrameIndex != -1);
        // [stackFrame] is not the first child of its parent. [left] should
        // equal the right value of its previous sibling.
        final CpuStackFrame previous = parent.children[stackFrameIndex - 1];
        left = stackFrameLefts[previous.id] +
            (widget.startingContentWidth * previous.totalTimeRatio);
      }
    }
    stackFrameLefts[stackFrame.id] = left;
    return left;
  }

  // TODO(kenz): base colors on categories (Widget, Render, Layer, User code,
  // etc.)
  Color _colorForStackFrame(CpuStackFrame stackFrame) {
    final color = uiColorPalette[_colorOffset % uiColorPalette.length];
    _colorOffset++;
    return color;
  }
}
