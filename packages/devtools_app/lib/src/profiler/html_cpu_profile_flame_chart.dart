// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../charts/flame_chart_canvas.dart';
import '../ui/colors.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/html_elements.dart';
import '../ui/theme.dart';
import 'cpu_profile_model.dart';
import 'html_cpu_profiler.dart';

class HtmlCpuFlameChart extends HtmlCpuProfilerView {
  HtmlCpuFlameChart(CpuProfileDataProvider profileDataProvider)
      : super(CpuProfilerViewType.flameChart, profileDataProvider) {
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

  CpuFlameChartCanvas canvas;

  CoreElement stackFrameDetails;

  @override
  void rebuildView() {
    reset();

    final CpuProfileData data = profileDataProvider();
    canvas = CpuFlameChartCanvas(
      data: data,
      width: element.clientWidth.toDouble(),
      height: math.max(
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

    stackFrameDetails.hidden(false);
  }

  @override
  void update({bool showLoadingSpinner = false}) {
    reset();
    super.update(showLoadingSpinner: showLoadingSpinner);
  }

  void updateForContainerResize() {
    if (canvas == null) {
      return;
    }

    final data = profileDataProvider();

    // Only update the canvas if the flame chart is visible and has data.
    // Otherwise, mark the canvas as needing a rebuild.
    if (!isHidden && data != null) {
      // We need to rebuild the canvas with a new content size so that the
      // canvas is always at least as tall as the container it is in. This
      // ensures that the grid lines in the chart will extend all the way to the
      // bottom of the container.
      canvas.forceRebuildForSize(
        canvas.calculatedWidthWithInsets,
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

  @override
  void reset() {
    if (canvas?.element?.element != null) {
      canvas.element.element.remove();
    }
    canvas = null;

    stackFrameDetails.text = stackFrameDetailsDefaultText;
    stackFrameDetails.hidden(true);
  }
}

class CpuFlameChartCanvas extends FlameChartCanvas<CpuProfileData> {
  CpuFlameChartCanvas({
    @required CpuProfileData data,
    @required double width,
    @required double height,
  }) : super(
          data: data,
          duration: data.profileMetaData.time.duration,
          width: width,
          height: height,
          classes: 'cpu-flame-chart',
        );

  static const stackFramePadding = 1;

  int _colorOffset = 0;

  @override
  double get calculatedWidth => rows[0].nodes[0].rect.right - sideInset;

  @override
  void initUiElements() {
    for (int i = 0; i < data.cpuProfileRoot.depth; i++) {
      rows.add(FlameChartRow(nodes: [], index: i));
    }

    final totalWidth = width - 2 * sideInset;

    final Map<String, double> stackFrameLefts = {};

    double leftForStackFrame(CpuStackFrame stackFrame) {
      final CpuStackFrame parent = stackFrame.parent;
      double left;
      if (parent == null) {
        left = sideInset;
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
      final left = leftForStackFrame(stackFrame);
      final top = row * rowHeightWithPadding + topOffset;
      final backgroundColor = _colorForStackFrame(stackFrame);

      final node = FlameChartNode<CpuStackFrame>(
        Rect.fromLTRB(left, top, left + width, top + rowHeight),
        backgroundColor,
        Colors.black,
        Colors.black,
        stackFrame,
        (_) => stackFrame.name,
        sideInset,
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

  // TODO(kenz): base colors on categories (Widget, Render, Layer, User code,
  // etc.)
  Color _colorForStackFrame(CpuStackFrame stackFrame) {
    final color = uiColorPalette[_colorOffset % uiColorPalette.length];
    _colorOffset++;
    return color;
  }
}
