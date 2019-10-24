// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:html_shim/html.dart';
import 'package:meta/meta.dart';

import '../charts/flame_chart_canvas.dart';
import '../ui/colors.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import 'timeline_model.dart';

class FrameBasedTimelineFlameChartCanvas
    extends FlameChartCanvas<TimelineFrame> {
  FrameBasedTimelineFlameChartCanvas({
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
    final uiSectionLabel = sectionLabel(
      'UI',
      mainUiColor,
      top: getTopForRow(0),
      width: 24.0,
    );
    rows[0].nodes.add(uiSectionLabel);

    // Add GPU section label.
    final gpuSectionLabel = sectionLabel(
      'GPU',
      mainGpuColor,
      top: getTopForRow(gpuSectionStartRow),
      width: 42.0,
    );
    rows[gpuSectionStartRow].nodes.add(gpuSectionLabel);

    void createChartNodes(TimelineEvent event, int row) {
      // Pixels per microsecond in order to fit the entire frame in view.
      final double pxPerMicro =
          totalStartingWidth / data.time.duration.inMicroseconds;

      // Do not round these values. Rounding the left could cause us to have
      // inaccurately placed events on the chart. Rounding the width could cause
      // us to lose very small events if the width rounds to zero.
      final double left =
          (event.time.start.inMicroseconds - frameStartOffset) * pxPerMicro +
              startInset;
      final double right =
          (event.time.end.inMicroseconds - frameStartOffset) * pxPerMicro +
              startInset;
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
        startInset,
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
        startInset;
  }

  @override
  double relativeYPosition(double absoluteY) {
    final row = (absoluteY - topOffset) ~/ rowHeightWithPadding;
    if (row >= gpuSectionStartRow) {
      return absoluteY - topOffset - sectionSpacing;
    }
    return absoluteY - topOffset;
  }
}

// TODO(kenz): color section backgrounds and alternate.
// TODO(kenz): draw tree hierarchy lines between async events=
// TODO(kenz): give top level children a secondary highlight color when a node
// is selected.
// TODO(kenz): make section label column resizeable.
// TODO(kenz): make sections collapsible

class FullTimelineFlameChartCanvas extends FlameChartCanvas<FullTimelineData> {
  FullTimelineFlameChartCanvas({
    @required FullTimelineData data,
    @required double width,
    @required double height,
  }) : super(
          data: data,
          duration: data.time.duration,
          width: width,
          height: height,
          startInset: _calculateStartInset(data),
          // TODO(kenz): investigate if we need to be smarter here to avoid
          // overflow in zooming calculations?
          maxZoomLevel: 40000,
        );

  static Map<String, double> sectionLabelWidths = {};

  static double maxSectionLabelWidth = 0.0;

  static double _calculateStartInset(FullTimelineData data) {
    final measurementCanvas = CanvasElement().context2D
      ..font = fontStyleToCss(const TextStyle(fontSize: fontSize));
    for (String bucketName in data.eventBuckets.keys) {
      final measuredWidth =
          measurementCanvas.measureText(bucketName).width.toDouble();
      maxSectionLabelWidth = measuredWidth > maxSectionLabelWidth
          ? measuredWidth
          : maxSectionLabelWidth;
      sectionLabelWidths[bucketName] = measuredWidth;
    }
    return maxSectionLabelWidth + 18.0;
  }

  int widestRow = -1;

  @override
  void initRows() {
    final int startTimeOffset = data.time.start.inMicroseconds;

    double getTopForRow(int row, int section) {
      // This accounts for section spacing between different threads of events.
      final additionalPadding = section * sectionSpacing;
      return (row * rowHeightWithPadding + topOffset + additionalPadding)
          .toDouble();
    }

    double maxRight = -1;

    void expandRowsToFitCurrentRow(int row) {
      if (row >= rows.length) {
        rows.addAll(List.generate(
          row - rows.length + 1,
          (i) => FlameChartRow(nodes: [], index: i),
        ));
      }
    }

    void createChartNodes(TimelineEvent event, int row, int section) {
      // TODO(kenz): we should do something more clever here by inferring the
      // missing start/end time based on ancestors/children. Skip for now.
      if (!event.isWellFormed) return;

      expandRowsToFitCurrentRow(row);

      // Pixels per microsecond in order to fit the entire frame in view.
      final double pxPerMicro =
          totalStartingWidth / data.time.duration.inMicroseconds;

      // Do not round these values. Rounding the left could cause us to have
      // inaccurately placed events on the chart. Rounding the width could cause
      // us to lose very small events if the width rounds to zero.
      final top = getTopForRow(row, section);
      final double left =
          (event.time.start.inMicroseconds - startTimeOffset) * pxPerMicro +
              startInset;
      final double right =
          (event.time.end.inMicroseconds - startTimeOffset) * pxPerMicro +
              startInset;
      if (right > maxRight) {
        maxRight = right;
        widestRow = row;
      }

      Color backgroundColor;
      if (event.isAsyncEvent) {
        backgroundColor = _nextAsyncColor();
      } else if (event.isUiEvent) {
        backgroundColor = _nextUiColor();
      } else if (event.isGpuEvent) {
        backgroundColor = _nextGpuColor();
      } else {
        backgroundColor = _nextUnknownColor();
      }

      Color textColor;
      if (event.isGpuEvent) {
        textColor = ThemedColor.fromSingleColor(contrastForegroundWhite);
      } else {
        textColor = ThemedColor.fromSingleColor(Colors.black);
      }

      final node = FlameChartNode<TimelineEvent>(
        Rect.fromLTRB(left, top, right, top + rowHeight),
        backgroundColor,
        textColor,
        Colors.black,
        event,
        (_) => event.name,
        startInset,
      );

      rows[row].nodes.add(node);

      var nextRow = row + 1;
      for (var child in event.children) {
        createChartNodes(child, nextRow, section);
        if (event.hasOverlappingChildren) {
          nextRow += child.displayDepth;
        }
      }
    }

    int currentRowIndex = 0;
    int currentSectionIndex = 0;

    for (String bucketName in data.eventBuckets.keys) {
      final List<TimelineEvent> bucket = data.eventBuckets[bucketName];
      int maxBucketDepth = 0;
      for (TimelineEvent event in bucket) {
        _resetColorOffsets();
        maxBucketDepth = math.max(maxBucketDepth, event.displayDepth);
        createChartNodes(event, currentRowIndex, currentSectionIndex);
      }

      final section = FlameChartSection(
        currentSectionIndex,
        startRow: currentRowIndex,
        endRow: currentRowIndex + maxBucketDepth,
        absStartY: getTopForRow(currentRowIndex, currentSectionIndex),
      );
      sections.add(section);

      // Add section label node.
      Color sectionLabelBackgroundColor;
      switch (bucketName) {
        case FullTimelineData.uiKey:
          sectionLabelBackgroundColor = mainUiColor;
          break;
        case FullTimelineData.gpuKey:
          sectionLabelBackgroundColor = mainGpuColor;
          break;
        case FullTimelineData.unknownKey:
          sectionLabelBackgroundColor = mainUnknownColor;
          break;
        default:
          sectionLabelBackgroundColor = mainAsyncColor;
      }

      // Padding necessary to ensure section labels fit in their respective
      // [FlameChartNode]s.
      const sectionLabelPadding = 13.0;

      final currentSectionLabel = sectionLabel(
        bucketName,
        sectionLabelBackgroundColor,
        top: getTopForRow(currentRowIndex, currentSectionIndex),
        width: math.max(
          FlameChartNode.minWidthForText,
          sectionLabelWidths[bucketName] + sectionLabelPadding,
        ),
      );
      rows[currentRowIndex].nodes.insert(0, currentSectionLabel);

      // Increment for next section.
      currentRowIndex += maxBucketDepth;
      currentSectionIndex++;
    }
  }

  @override
  double get calculatedWidth =>
      rows[widestRow].nodes.last.rect.right - startInset;

  @override
  num get zoomMultiplier => zoomLevel * 0.008;

  @override
  double relativeYPosition(double absoluteY) {
    final section = sections
            .lastWhere(
              (s) => absoluteY >= s.absStartY,
              orElse: () => null,
            )
            ?.index ??
        0;
    return absoluteY - topOffset - (section * sectionSpacing);
  }
}

int _uiColorOffset = 0;

Color _nextUiColor() {
  final color = uiColorPalette[_uiColorOffset % uiColorPalette.length];
  _uiColorOffset++;
  return color;
}

int _gpuColorOffset = 0;

Color _nextGpuColor() {
  final color = gpuColorPalette[_gpuColorOffset % gpuColorPalette.length];
  _gpuColorOffset++;
  return color;
}

int _asyncColorOffset = 0;

Color _nextAsyncColor() {
  final color = asyncColorPalette[_asyncColorOffset % asyncColorPalette.length];
  _asyncColorOffset++;
  return color;
}

int _unknownColorOffset = 0;

Color _nextUnknownColor() {
  final color =
      unknownColorPalette[_unknownColorOffset % unknownColorPalette.length];
  _unknownColorOffset++;
  return color;
}

void _resetColorOffsets() {
  _asyncColorOffset = 0;
  _uiColorOffset = 0;
  _gpuColorOffset = 0;
  _unknownColorOffset = 0;
}
