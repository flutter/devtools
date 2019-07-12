// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../charts/flame_chart_canvas.dart';
import '../ui/colors.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import 'cpu_profile_model.dart';
import 'cpu_profiler.dart';

class CpuFlameChart extends CpuProfilerView {
  CpuFlameChart(CpuProfileDataProvider getProfileData)
      : super(CpuProfilerViewType.flameChart, getProfileData) {
    stackFrameDetails = div(c: 'event-details-heading stack-frame-details')
      ..element.style.backgroundColor = colorToCss(stackFrameDetailsBackground)
      ..hidden(true);

    add(stackFrameDetails);
  }

  static const String stackFrameDetailsDefaultText =
      '[No stack frame selected]';

  static const stackFrameDetailsBackground = ThemedColor(
    Color(0xFFF6F6F6),
    Color(0xFF202124),
  );

  FlameChartCanvas canvas;

  CoreElement stackFrameDetails;

  @override
  void rebuildView() {
    final CpuProfileData data = getProfileData();
    canvas = CpuProfileFlameChart(
      data: data,
      flameChartWidth: element.clientWidth,
      flameChartHeight: math.max(
        // Subtract [rowHeightWithPadding] to account for timeline at the top of
        // the flame chart.
        element.clientHeight - rowHeightWithPadding,
        // Add 1 to account for a row of padding at the bottom of the chart.
        (data.cpuProfileRoot.depth + 1) * rowHeightWithPadding,
      ),
    );

    canvas.onNodeSelected.listen((node) {
      assert(node.data is CpuStackFrame);
      stackFrameDetails.text = node.data.toString();
    });

    add(canvas.element);

    stackFrameDetails
      ..text = stackFrameDetailsDefaultText
      ..hidden(false);
  }

  @override
  void update() {
    reset();
    super.update();
  }

  void updateForContainerResize() {
    if (canvas == null) {
      return;
    }

    final data = getProfileData();

    // Only update the canvas if the flame chart is visible and has data.
    // Otherwise, mark the canvas as needing a rebuild.
    if (!isHidden && data != null) {
      // We need to rebuild the canvas with a new content size so that the
      // canvas is always at least as tall as the container it is in. This
      // ensures that the grid lines in the chart will extend all the way to the
      // bottom of the container.
      canvas.forceRebuildForSize(
        canvas.flameChartWidthWithInsets,
        math.max(
          // Subtract [rowHeightWithPadding] to account for the size of
          // [stackFrameDetails] section at the bottom of the chart.
          element.scrollHeight.toDouble() - rowHeightWithPadding,
          // Add 1 to account for a row of padding at the bottom of the chart.
          (data.cpuProfileRoot.depth + 1) * rowHeightWithPadding,
        ),
      );
    } else {
      viewNeedsRebuild = true;
    }
  }

  void reset() {
    if (canvas?.element?.element != null) {
      canvas.element.element.remove();
    }
    canvas = null;

    stackFrameDetails.text = stackFrameDetailsDefaultText;
    stackFrameDetails.hidden(true);
  }
}

class CpuProfileFlameChart extends FlameChartCanvas<CpuProfileData> {
  CpuProfileFlameChart({
    @required CpuProfileData data,
    @required flameChartWidth,
    @required flameChartHeight,
  }) : super(
          data: data,
          duration: data.time.duration,
          flameChartWidth: flameChartWidth,
          flameChartHeight: flameChartHeight,
          classes: 'cpu-flame-chart',
        );

  static const stackFramePadding = 1;

  int _colorOffset = 0;

  @override
  void initRows() {
    for (int i = 0; i < data.cpuProfileRoot.depth; i++) {
      rows.add(FlameChartRow(nodes: [], index: i));
    }

    final totalWidth = flameChartWidth - 2 * flameChartInset;

    final Map<String, double> stackFrameLefts = {};

    double calculateLeftForStackFrame(CpuStackFrame stackFrame) {
      final CpuStackFrame parent = stackFrame.parent;
      double left;
      if (parent == null) {
        left = flameChartInset.toDouble();
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
              (totalWidth * previous.totalTimeRatio);
        }
      }
      stackFrameLefts[stackFrame.id] = left;
      return left;
    }

    void createChartNodes(CpuStackFrame stackFrame, int row) {
      final double width =
          totalWidth * stackFrame.totalTimeRatio - stackFramePadding;
      final left = calculateLeftForStackFrame(stackFrame);
      final top = (row * rowHeightWithPadding + flameChartTop).toDouble();

      final node = FlameChartNode<CpuStackFrame>(
        Rect.fromLTRB(left, top, left + width, top + flameChartRowHeight),
        getColorForNode(stackFrame),
        Colors.black,
        Colors.black,
        stackFrame,
        (_) => stackFrame.name,
      );

      rows[row].nodes.add(node);

      for (CpuStackFrame child in stackFrame.children) {
        createChartNodes(
          child,
          row + 1,
        );
      }
    }

    createChartNodes(data.cpuProfileRoot, 0);
  }

  // TODO(kenzie): base colors on categories (Widget, Render, Layer, User code,
  // etc.)
  @override
  Color getColorForNode(dynamic node) {
    assert(node is CpuStackFrame);
    final color = uiColorPalette[_colorOffset % uiColorPalette.length];
    _colorOffset++;
    return color;
  }

  @override
  double getFlameChartWidth() {
    return rows[0].nodes[0].rect.right - flameChartInset;
  }
}
