// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../charts/flame_chart_canvas.dart';
import '../ui/colors.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/theme.dart';
import 'timeline_model.dart';

class TimelineFlameChartCanvas extends FlameChartCanvas<TimelineFrame> {
  TimelineFlameChartCanvas({
    @required TimelineFrame data,
    @required double width,
    @required double height,
  }) : super(
          data: data,
          duration: data.time.duration,
          width: width,
          height: height,
        );

  static const double sectionSpacing = 15.0;

  int get gpuSectionStartRow => data.uiEventFlow.depth;

  @override
  void initRows() {
    rows = List.generate(
      data.uiEventFlow.depth + data.gpuEventFlow.depth,
      (i) => FlameChartRow(nodes: [], index: i),
    );

    final totalWidth = width - 2 * sideInset;

    final int frameStartOffset = data.time.start.inMicroseconds;

    double getTopForRow(int row) {
      // This accounts for the section spacing between the UI events and the GPU
      // events.
      final additionalPadding =
          row >= gpuSectionStartRow ? sectionSpacing : 0.0;
      return (row * rowHeightWithPadding + topOffset + additionalPadding)
          .toDouble();
    }

    // Add UI section label.
    const uiLabelWidth = 22.0 + rowPadding;
    final uiLabelTop = getTopForRow(0);
    final uiLabelBottom = uiLabelTop + rowHeight;
    final uiSectionLabel = FlameChartNode<TimelineEvent>(
      Rect.fromLTRB(rowPadding, uiLabelTop, uiLabelWidth, uiLabelBottom),
      mainUiColor,
      Colors.black,
      Colors.black,
      null,
      (_) => 'UI',
    );
    rows[0].nodes.add(uiSectionLabel);

    // Add GPU section label.
    const gpuLabelWidth = 40.0 + rowPadding;
    final gpuLabelTop = getTopForRow(gpuSectionStartRow);
    final gpuLabelBottom = gpuLabelTop + rowHeight;
    final gpuSectionLabel = FlameChartNode<TimelineEvent>(
      Rect.fromLTRB(rowPadding, gpuLabelTop, gpuLabelWidth, gpuLabelBottom),
      mainGpuColor,
      Colors.white,
      Colors.white,
      null,
      (_) => 'GPU',
    );
    rows[gpuSectionStartRow].nodes.add(gpuSectionLabel);

    void createChartNodes(TimelineEvent event, int row) {
      // Pixels per microsecond in order to fit the entire frame in view.
      final double pxPerMicro = totalWidth / data.time.duration.inMicroseconds;

      // Do not round these values. Rounding the left could cause us to have
      // inaccurately placed events on the chart. Rounding the width could cause
      // us to lose very small events if the width rounds to zero.
      final double left =
          (event.time.start.inMicroseconds - frameStartOffset) * pxPerMicro +
              sideInset;
      final double right =
          (event.time.end.inMicroseconds - frameStartOffset) * pxPerMicro +
              sideInset;
      final top = getTopForRow(row);
      final backgroundColor =
          event.isUiEvent ? _nextUiColor() : _nextGpuColor();

      final node = FlameChartNode<TimelineEvent>(
        Rect.fromLTRB(left, top, right, top + rowHeight),
        backgroundColor,
        event.isUiEvent
            ? ThemedColor.fromSingleColor(Colors.black)
            : ThemedColor.fromSingleColor(contrastForegroundWhite),
        Colors.black,
        event,
        (_) => event.name,
      );

      rows[row].nodes.add(node);

      for (TimelineEvent child in event.children) {
        createChartNodes(
          child,
          row + 1,
        );
      }
    }

    createChartNodes(data.uiEventFlow, 0);
    createChartNodes(data.gpuEventFlow, gpuSectionStartRow);
  }

  @override
  double get calculatedWidth {
    // The farthest right node in the graph will either be the root UI event or
    // the root GPU event.
    return math.max(rows[gpuSectionStartRow].nodes.last.rect.right,
            rows[gpuSectionStartRow].nodes.last.rect.right) -
        sideInset;
  }

  @override
  double relativeYPosition(double absoluteY) {
    final row = (absoluteY - topOffset) ~/ rowHeightWithPadding;
    if (row >= gpuSectionStartRow) {
      return absoluteY - topOffset - sectionSpacing;
    }
    return absoluteY - topOffset;
  }

  int _uiColorOffset = 0;

  int _gpuColorOffset = 0;

  Color _nextUiColor() {
    final color = uiColorPalette[_uiColorOffset % uiColorPalette.length];
    _uiColorOffset++;
    return color;
  }

  Color _nextGpuColor() {
    final color = gpuColorPalette[_gpuColorOffset % gpuColorPalette.length];
    _gpuColorOffset++;
    return color;
  }
}
