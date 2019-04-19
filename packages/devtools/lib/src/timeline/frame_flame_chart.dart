// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import '../ui/drag_scroll.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'flame_chart.dart';
import 'timeline.dart';
import 'timeline_protocol.dart';

// TODO(kenzie): port all of this code to use flame_chart_canvas.dart.

// Light Blue 50: 200-400 (light mode) - see https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
// Blue Material Dark: 200-400 (dark mode) - see https://standards.google/guidelines/google-material/color/dark-theme.html#style.
final uiColorPalette = [
  const ThemedColor(mainUiColorLight, mainUiColorDark),
  const ThemedColor(Color(0xFF4FC3F7), Color(0xFF8AB4F7)),
  const ThemedColor(Color(0xFF29B6F6), Color(0xFF669CF6)),
];

// Light Blue 50: 700-900 (light mode) - see https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
// Blue Material Dark: 500-700 (dark mode) - see https://standards.google/guidelines/google-material/color/dark-theme.html#style.
final gpuColorPalette = [
  const ThemedColor(mainGpuColorLight, mainGpuColorDark),
  const ThemedColor(Color(0xFF0277BD), Color(0xFF1966D2)),
  const ThemedColor(Color(0xFF01579B), Color(0xFF1859BD)),
];

final StreamController<FrameFlameChartItem>
    _selectedFrameFlameChartItemController =
    StreamController<FrameFlameChartItem>.broadcast();

Stream<FrameFlameChartItem> get onSelectedFrameFlameChartItem =>
    _selectedFrameFlameChartItemController.stream;

final DragScroll _dragScroll = DragScroll();

const _flameChartInset = 70;

class FrameFlameChart extends FlameChart<TimelineFrame> {
  FrameFlameChart()
      : super(
          onSelectedFlameChartItem: onSelectedFrameFlameChartItem,
          dragScroll: _dragScroll,
          classes: 'section-border flame-chart-container',
          flameChartInset: _flameChartInset,
        );

  static const int sectionSpacing = 15;

  TimelineGrid _timelineGrid;
  CoreElement _flameChart;
  CoreElement _timelineBackground;
  CoreElement _uiSection;
  CoreElement _gpuSection;

  int _uiColorOffset = 0;
  int _gpuColorOffset = 0;

  Color nextUiColor() {
    final color = uiColorPalette[_uiColorOffset % uiColorPalette.length];
    _uiColorOffset++;
    return color;
  }

  Color nextGpuColor() {
    final color = gpuColorPalette[_gpuColorOffset % gpuColorPalette.length];
    _gpuColorOffset++;
    return color;
  }

  @override
  void reset() {
    super.reset();
    _uiColorOffset = 0;
    _gpuColorOffset = 0;
  }

  @override
  void render() {
    final TimelineFrame frame = data;

    /// Pixels per microsecond in order to fit the entire frame in view.
    ///
    /// Subtract 2 * [sectionLabelOffset] to account for extra space at the
    /// beginning/end of the chart.
    final double pxPerMicro = (element.clientWidth - 2 * flameChartInset) /
        frame.time.duration.inMicroseconds;

    final int frameStartOffset = frame.time.start.inMicroseconds;
    final uiSectionHeight =
        frame.uiEventFlow.depth * FlameChart.rowHeight + sectionSpacing;
    final gpuSectionHeight = frame.gpuEventFlow.depth * FlameChart.rowHeight;
    final flameChartHeight =
        2 * FlameChart.rowHeight + uiSectionHeight + gpuSectionHeight;

    void drawSubtree(
      TimelineEvent event,
      int row,
      CoreElement section, {
      bool includeDuration = false,
    }) {
      // Do not round these values. Rounding the left could cause us to have
      // inaccurately placed events on the chart. Rounding the width could cause
      // us to lose very small events if the width rounds to zero.
      final double startPx =
          (event.time.start.inMicroseconds - frameStartOffset) * pxPerMicro;
      final double endPx =
          (event.time.end.inMicroseconds - frameStartOffset) * pxPerMicro;

      _drawFlameChartItem(
        event,
        startPx,
        endPx - startPx,
        row * FlameChart.rowHeight + FlameChart.padding,
        section,
        includeDuration: includeDuration,
      );

      for (TimelineEvent child in event.children) {
        drawSubtree(child, row + 1, section);
      }
    }

    void drawTimelineBackground() {
      _timelineBackground = div(c: 'timeline-background')
        ..element.style.height = '${FlameChart.rowHeight}px';
      add(_timelineBackground);
    }

    void drawUiEvents() {
      _uiSection = div(c: 'flame-chart-section ui');
      _flameChart.add(_uiSection);

      _uiSection.element.style
        ..height = '${uiSectionHeight}px'
        ..top = '${FlameChart.rowHeight}px';

      final sectionTitle =
          div(text: 'UI', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainUiColor)
        ..left = '${FlameChart.padding}px'
        ..top = '${FlameChart.padding}px';
      _uiSection.add(sectionTitle);

      drawSubtree(
        frame.uiEventFlow,
        0,
        _uiSection,
        includeDuration: true,
      );
    }

    void drawGpuEvents() {
      _gpuSection = div(c: 'flame-chart-section');
      _flameChart.add(_gpuSection);

      _gpuSection.element.style
        ..height = '${gpuSectionHeight}px'
        ..top = '${FlameChart.rowHeight + uiSectionHeight}px';

      final sectionTitle =
          div(text: 'GPU', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainGpuColor)
        ..left = '${FlameChart.padding}px'
        ..top = '${FlameChart.padding}px';
      _gpuSection.add(sectionTitle);

      drawSubtree(
        frame.gpuEventFlow,
        0,
        _gpuSection,
        includeDuration: true,
      );
    }

    void drawTimelineGrid() {
      _timelineGrid = TimelineGrid(
        frame.time.duration,
        getFlameChartWidth(),
      );
      _timelineGrid.element.style.height = '${flameChartHeight}px';
      add(_timelineGrid);
    }

    _flameChart = div(c: 'flame-chart')
      ..flex()
      ..layoutVertical();
    _flameChart.element.style.height = '${flameChartHeight}px';
    add(_flameChart);

    drawTimelineBackground();
    drawUiEvents();
    drawGpuEvents();
    drawTimelineGrid();

    _setSectionWidths();
  }

  void _drawFlameChartItem(
    TimelineEvent event,
    num left,
    num width,
    num top,
    CoreElement section, {
    bool includeDuration = false,
  }) {
    final item = FrameFlameChartItem(
      event,
      left,
      width,
      top,
      event.isUiEvent ? nextUiColor() : nextGpuColor(),
      event.isUiEvent ? Colors.black : contrastForegroundWhite,
      Colors.black,
      includeDuration: includeDuration,
    );
    addItemToFlameChart(item, section);
  }

  void _setSectionWidths() {
    // Add 2 * [flameChartInset] to account for spacing at the beginning and end
    // of the chart.
    final width = getFlameChartWidth() + 2 * flameChartInset;
    _flameChart.element.style.width = '${width}px';
    _timelineBackground.element.style.width = '${width}px';
    _uiSection.element.style.width = '${width}px';
    _gpuSection.element.style.width = '${width}px';
  }

  @override
  void updateChartForZoom() {
    super.updateChartForZoom();

    _setSectionWidths();
    _timelineGrid.updateForZoom(zoomLevel, getFlameChartWidth());

    element.scrollLeft = math.max(0, floatingPointScrollLeft.round());
  }
}

class FrameFlameChartItem extends FlameChartItem {
  FrameFlameChartItem(
    this._event,
    num startingLeft,
    num startingWidth,
    num top,
    Color backgroundColor,
    Color defaultTextColor,
    Color selectedTextColor, {
    this.includeDuration = false,
  }) : super(
          startingLeft: startingLeft,
          startingWidth: startingWidth,
          top: top,
          backgroundColor: backgroundColor,
          defaultTextColor: defaultTextColor,
          selectedTextColor: selectedTextColor,
          flameChartInset: _flameChartInset,
        );

  TimelineEvent get event => _event;
  final TimelineEvent _event;
  final bool includeDuration;

  @override
  void setText() {
    final durationText = msText(event.time.duration);

    String title = _event.name;
    element.title = '$title ($durationText)';

    if (includeDuration) {
      title = '$title ($durationText)';
    }

    itemLabel.text = title;
  }

  @override
  void setOnClick() {
    element.onClick.listen((e) {
      // Prevent clicks when the chart was being dragged.
      if (!_dragScroll.wasDragged) {
        _selectedFrameFlameChartItemController.add(this);
      }
    });
  }
}

class TimelineGrid extends CoreElement {
  TimelineGrid(this._frameDuration, this._flameChartWidth)
      : super('div', classes: 'flame-chart-grid') {
    flex();
    layoutHorizontal();
    _initializeGrid(baseGridInterval);
  }

  static const baseGridInterval = 150;

  final Duration _frameDuration;

  num _zoomLevel = 1;

  num _flameChartWidth;

  num get _flameChartWidthWithInsets => _flameChartWidth + 2 * _flameChartInset;

  final List<TimelineGridItem> _gridItems = [];

  void _initializeGrid(num interval) {
    // Draw the first grid item since it will have a different width than the
    // rest.
    final gridItem =
        TimelineGridItem(0, _flameChartInset, const Duration(microseconds: 0));
    _gridItems.add(gridItem);
    add(gridItem);

    num left = _flameChartInset;

    while (left + interval < _flameChartWidthWithInsets) {
      // TODO(kenzie): Instead of calculating timestamp based on position, track
      // timestamp var and increment it by time interval represented by each
      // grid item. See comment on https://github.com/flutter/devtools/pull/325.
      final Duration timestamp =
          Duration(microseconds: getTimestampForPosition(left + interval));
      final gridItem = TimelineGridItem(left, interval, timestamp);

      _gridItems.add(gridItem);
      add(gridItem);

      left += interval;
    }
  }

  /// Returns the timestamp rounded to the nearest microsecond for the
  /// x-position.
  int getTimestampForPosition(num gridItemEnd) {
    return ((gridItemEnd - _flameChartInset) /
            _flameChartWidth *
            _frameDuration.inMicroseconds)
        .round();
  }

  void updateForZoom(num newZoomLevel, num newFlameChartWidth) {
    if (_zoomLevel == newZoomLevel) {
      return;
    }

    _flameChartWidth = newFlameChartWidth;
    element.style.width = '${_flameChartWidthWithInsets}px';

    final log2ZoomLevel = log2(_zoomLevel);
    final log2NewZoomLevel = log2(newZoomLevel);

    final gridZoomFactor = math.pow(2, log2NewZoomLevel);
    final gridIntervalPx = baseGridInterval / gridZoomFactor;

    /// The physical pixel width of the grid interval at [newZoomLevel].
    final zoomedGridIntervalPx = gridIntervalPx * newZoomLevel;

    // TODO(kenzie): add tests for grid drawing and zooming logic.
    if (log2NewZoomLevel == log2ZoomLevel) {
      // Don't modify the first grid item. This item will have a fixed left of
      // 0, width of [flameChartInset], and timestamp of '0.0 ms'.
      for (int i = 1; i < _gridItems.length; i++) {
        final currentItem = _gridItems[i];

        final newLeft = _flameChartInset + zoomedGridIntervalPx * (i - 1);
        currentItem.setPosition(newLeft, zoomedGridIntervalPx);
      }
    } else {
      clear();
      _gridItems.clear();
      _initializeGrid(zoomedGridIntervalPx);
    }

    _zoomLevel = newZoomLevel;
  }
}

/// Describes a single item in the frame chart's timeline grid.
///
/// A single item consists of a line and a timestamp describing the location
/// in the overall timeline [TimelineGrid].
class TimelineGridItem extends CoreElement {
  TimelineGridItem(this.currentLeft, this.currentWidth, this.timestamp)
      : super('div', classes: 'flame-chart-grid-item') {
    _initGridItem();
  }

  static const gridLineWidth = 1;
  static const timestampPadding = 4;

  final Duration timestamp;
  num currentLeft;
  num currentWidth;

  /// The timestamp label for this grid item.
  CoreElement timestampLabel;

  /// The line for this grid item.
  CoreElement gridLine;

  void _initGridItem() {
    gridLine = div(c: 'grid-line');
    add(gridLine);

    timestampLabel = div(c: 'timestamp')
      ..element.style.color = colorToCss(contrastForeground);
    // TODO(kenzie): add more advanced logic for rounding the timestamps. See
    // https://github.com/flutter/devtools/issues/329.
    timestampLabel.text = msText(
      timestamp,
      fractionDigits: timestamp.inMicroseconds == 0 ? 1 : 3,
    );
    add(timestampLabel);

    setPosition(currentLeft, currentWidth);
  }

  void setPosition(num left, num width) {
    currentLeft = left;
    currentWidth = width;

    element.style
      ..left = '${left}px'
      ..width = '${width}px';

    // Update [gridLine] position.
    gridLine.element.style.left = '${width - gridLineWidth}px';

    // Update [timestampLabel] position.
    timestampLabel.element.style.width = '${width - 2 * timestampPadding}px';
  }
}
