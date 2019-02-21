// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../ui/drag_scroll.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../utils.dart';
import 'timeline.dart';
import 'timeline_protocol.dart';

// TODO(kenzie): implement zoom functionality.

// Switch this flag to true to dump the frame event trace to console.
bool _debugEventTrace = false;

// Blue 100-300 color palette from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const cpuColorPalette = [
  Color(0xFFBBDEFB),
  Color(0xFF90CAF9),
  mainCpuColor,
];

// Teal 100-300 color palette from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const gpuColorPalette = [
  Color(0xFFB2DFDB),
  Color(0xFF80CBC4),
  mainGpuColor,
];

const cpuSectionBackground = Color(0xFFF9F9F9);
const gpuSectionBackground = Color(0xFFF3F3F3);

/// Inset for the start/end of the flame chart.
const flameChartInset = 70;

final StreamController<FlameChartItem> _selectedFlameChartItemController =
    StreamController<FlameChartItem>.broadcast();

Stream<FlameChartItem> get onSelectedFlameChartItem =>
    _selectedFlameChartItemController.stream;

final DragScroll _dragScroll = DragScroll();

class FrameFlameChart extends CoreElement {
  FrameFlameChart() : super('div', classes: 'section-border') {
    flex();
    layoutVertical();
    element.style
      ..backgroundColor = colorToCss(gpuSectionBackground)
      ..position = 'relative'
      ..marginTop = '4px'
      ..overflow = 'hidden';

    _dragScroll.enableDragScrolling(this);
    element.onMouseWheel.listen(_handleMouseWheel);

    onSelectedFlameChartItem.listen((FlameChartItem item) {
      // Unselect the previously selected item.
      _selectedItem?.setSelected(false);

      // Select the new item.
      item.setSelected(true);
      _selectedItem = item;
    });
  }

  static const padding = 2;

  /// All flame chart items currently drawn on the chart.
  final List<FlameChartItem> _chartItems = [];

  /// Maximum zoom level we should allow.
  ///
  /// Arbitrary large number to accommodate spacing for some of the shortest
  /// events when zoomed in to [_maxZoomLevel].
  final _maxZoomLevel = 150;
  final _minZoomLevel = 1;
  num _zoomLevel = 1;

  /// Maximum scroll delta allowed for scrollwheel based zooming.
  ///
  /// This isn't really needed but is a reasonable for safety in case we
  /// aren't handling some mouse based scroll wheel behavior well, etc.
  final num maxScrollWheelDelta = 20;

  num get _zoomMultiplier => _zoomLevel * 0.003;

  // The DOM doesn't allow floating point scroll offsets so we track a
  // theoretical floating point scroll offset corresponding to the current
  // scroll offset to reduce floating point error when zooming.
  num floatingPointScrollLeft = 0;

  FlameChartItem _selectedItem;

  TimelineFrame _frame;
  TimelineGrid _timelineGrid;
  CoreElement _cpuSection;
  CoreElement _gpuSection;

  int _cpuColorOffset = 0;
  int _gpuColorOffset = 0;

  Color nextCpuColor() {
    final color = cpuColorPalette[_cpuColorOffset % cpuColorPalette.length];
    _cpuColorOffset++;
    return color;
  }

  Color nextGpuColor() {
    final color = gpuColorPalette[_gpuColorOffset % gpuColorPalette.length];
    _gpuColorOffset++;
    return color;
  }

  void updateFrameData(TimelineFrame frame) {
    _frame = frame;
    _resetChart();

    if (_debugEventTrace && frame != null) {
      final StringBuffer buf = new StringBuffer();
      buf.writeln('CPU for frame ${frame.id}:');
      frame.cpuEventFlow.format(buf, '  ');
      buf.writeln('GPU for frame ${frame.id}:');
      frame.gpuEventFlow.format(buf, '  ');
      print(buf.toString());
    }

    if (frame != null) {
      _render();
    }
  }

  void _resetChart() {
    clear();
    element.scrollLeft = 0;
    element.scrollTop = 0;
    _cpuColorOffset = 0;
    _gpuColorOffset = 0;
    _zoomLevel = 1;
    _chartItems.clear();
  }

  void _render() {
    const int rowHeight = 25;
    const int sectionSpacing = 15;

    /// Pixels per microsecond in order to fit the entire frame in view.
    ///
    /// Subtract 2 * [sectionLabelOffset] to account for extra space at the
    /// beginning/end of the chart.
    final num pxPerMicro =
        (element.clientWidth - 2 * flameChartInset) / _frame.duration;

    final int frameStartOffset = _frame.startTime;
    final cpuSectionHeight =
        _frame.cpuEventFlow.depth * rowHeight + sectionSpacing;
    final gpuSectionHeight = _frame.gpuEventFlow.depth * rowHeight;

    void drawRecursively(
      TimelineEvent event,
      int row,
      CoreElement section, {
      bool includeDuration = false,
    }) {
      // Do not round these values. Rounding the left could cause us to have
      // inaccurately placed events on the chart. Rounding the width could cause
      // us to lose very small events if the width rounds to zero.
      final double startPx = (event.startTime - frameStartOffset) * pxPerMicro;
      final double endPx = (event.endTime - frameStartOffset) * pxPerMicro;

      _drawFlameChartItem(
        event,
        startPx,
        endPx - startPx,
        row * rowHeight + padding,
        section,
        includeDuration: includeDuration,
      );

      for (TimelineEvent child in event.children) {
        drawRecursively(child, row + 1, section);
      }
    }

    void drawCpuEvents() {
      _cpuSection = div(c: 'flame-chart-section');
      add(_cpuSection);

      _cpuSection.element.style
        ..height = '${cpuSectionHeight}px'
        ..top = '${rowHeight}px'
        ..backgroundColor = colorToCss(cpuSectionBackground);

      final sectionTitle =
          div(text: 'CPU', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainCpuColor)
        ..left = '${padding}px'
        ..top = '${padding}px';
      _cpuSection.add(sectionTitle);

      drawRecursively(
        _frame.cpuEventFlow,
        0,
        _cpuSection,
        includeDuration: true,
      );
    }

    void drawGpuEvents() {
      _gpuSection = div(c: 'flame-chart-section');
      add(_gpuSection);

      _gpuSection.element.style
        ..height = '${gpuSectionHeight}px'
        ..top = '${rowHeight + cpuSectionHeight}px';

      final sectionTitle =
          div(text: 'GPU', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainGpuColor)
        ..left = '${padding}px'
        ..top = '${padding}px';
      _gpuSection.add(sectionTitle);

      drawRecursively(
        _frame.gpuEventFlow,
        0,
        _gpuSection,
        includeDuration: true,
      );
    }

    void drawTimelineGrid() {
      _timelineGrid = TimelineGrid(_frame.durationMs, getFlameChartWidth());
      add(_timelineGrid);
    }

    drawCpuEvents();
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
    final item = FlameChartItem(
      event,
      left,
      width,
      top,
      event.isCpuEvent ? nextCpuColor() : nextGpuColor(),
      includeDuration: includeDuration,
    );

    _chartItems.add(item);
    section.element.append(item.e);
  }

  void _setSectionWidths() {
    // Add 2 * [flameChartInset] to account for spacing at the beginning and end
    // of the chart.
    final width = getFlameChartWidth() + 2 * flameChartInset;
    _cpuSection.element.style.width = '${width}px';
    _gpuSection.element.style.width = '${width}px';
  }

  num getFlameChartWidth() {
    num maxRight = 0;
    for (FlameChartItem item in _chartItems) {
      if ((item.currentLeft + item.currentWidth) > maxRight) {
        maxRight = item.currentLeft + item.currentWidth;
      }
    }
    // Subtract [flameChartInset] to account for spacing at the beginning of the
    // chart.
    return maxRight - flameChartInset;
  }

  void _handleMouseWheel(WheelEvent e) {
    e.preventDefault();

    if (e.deltaY.abs() >= e.deltaX.abs()) {
      final mouseX = e.client.x - element.getBoundingClientRect().left;
      _handleZoom(e.deltaY, mouseX);
    } else {
      // Manually perform horizontal scrolling.
      element.scrollLeft += e.deltaX;
    }
  }

  void _handleZoom(num deltaY, num mouseX) {
    assert(_frame != null);

    deltaY = deltaY.clamp(-maxScrollWheelDelta, maxScrollWheelDelta);
    num newZoomLevel = _zoomLevel + deltaY * _zoomMultiplier;
    newZoomLevel = newZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);

    if (newZoomLevel == _zoomLevel) return;
    // Store current scroll values for re-calculating scroll location on zoom.
    double lastScrollLeft = element.scrollLeft.toDouble();
    // Test whether the scroll offset has changed by more than rounding error
    // since the last time an exact scroll offset was calculated.
    if ((floatingPointScrollLeft - lastScrollLeft).abs() < 0.5) {
      lastScrollLeft = floatingPointScrollLeft;
    }
    // Position in the zoomable coordinate space that we want to keep fixed.
    final double fixedX = mouseX + lastScrollLeft - flameChartInset;
    // Calculate and set our new horizontal scroll position.
    if (fixedX >= 0) {
      floatingPointScrollLeft =
          fixedX * newZoomLevel / _zoomLevel + flameChartInset - mouseX;
    } else {
      // No need to transform as we are in the fixed portion of the window.
      floatingPointScrollLeft = lastScrollLeft;
    }
    _zoomLevel = newZoomLevel;

    for (FlameChartItem item in _chartItems) {
      item.updateHorizontalPosition(zoom: _zoomLevel);
    }
    _setSectionWidths();

    _timelineGrid.updateForZoom(_zoomLevel, getFlameChartWidth());

    element.scrollLeft = math.max(0, floatingPointScrollLeft.round());
  }
}

class FlameChartItem {
  FlameChartItem(
    this._event,
    this._startingLeft,
    this._startingWidth,
    this._top,
    this._backgroundColor, {
    bool includeDuration = false,
  }) {
    e = Element.div()..className = 'flame-chart-item';
    e.title = '${event.name} (${microsAsMsText(_event.duration)})';

    _labelWrapper = Element.div()..className = 'flame-chart-item-label-wrapper';
    String name = event.name;
    if (includeDuration) {
      name = '$name (${microsAsMsText(event.duration)})';
    }
    _label = Element.span()
      ..text = name
      ..className = 'flame-chart-item-label'
      ..style.color = colorToCss(defaultTextColor);
    _labelWrapper.append(_label);
    e.append(_labelWrapper);

    e.style
      ..background = colorToCss(_backgroundColor)
      ..top = '${_top}px';
    updateHorizontalPosition(zoom: 1);

    e.onClick.listen((e) {
      // Prevent clicks when the chart was being dragged.
      if (!_dragScroll.wasDragged) {
        _selectedFlameChartItemController.add(this);
      }
    });
  }

  static const defaultTextColor = Color(0xFF000000);
  static const selectedTextColor = Color(0xFFFFFFFF);
  // Pixels of padding to place on the right side of the label to ensure label
  // text does not get too close to the right hand size of each bar.
  static const labelPaddingRight = 4;

  Element e;
  Element _label;
  Element _labelWrapper;

  TimelineEvent get event => _event;
  final TimelineEvent _event;

  final num _top;
  final Color _backgroundColor;

  // Left and width values for a flame chart item at zoom level 1;
  final num _startingLeft;
  final num _startingWidth;

  num currentLeft;
  num currentWidth;

  Color get backgroundColor => _backgroundColor;

  void updateHorizontalPosition({@required num zoom}) {
    // Do not round these values. Rounding the left could cause us to have
    // inaccurately placed events on the chart. Rounding the width could cause
    // us to lose very small events if the width rounds to zero.
    final newLeft = flameChartInset + _startingLeft * zoom;
    final newWidth = _startingWidth * zoom;

    e.style.left = '${newLeft}px';
    if (_startingWidth != null) {
      e.style.width = '${newWidth}px';
      _labelWrapper.style.maxWidth =
          '${math.max(0, newWidth - labelPaddingRight)}px';
    }
    currentLeft = newLeft;
    currentWidth = newWidth;
  }

  void setSelected(bool selected) {
    e.style.backgroundColor =
        colorToCss(selected ? selectedColor : _backgroundColor);
    _label.style.color =
        colorToCss(selected ? selectedTextColor : defaultTextColor);
  }
}

class TimelineGrid extends CoreElement {
  TimelineGrid(this._frameDurationMs, this._flameChartWidth)
      : super('div', classes: 'flame-chart-grid') {
    flex();
    layoutHorizontal();
    _drawGrid(baseGridInterval);
  }

  static const baseGridInterval = 150;

  final num _frameDurationMs;

  num _zoomLevel = 1;

  num _flameChartWidth;

  num get _flameChartWidthWithInsets => _flameChartWidth + 2 * flameChartInset;

  final List<TimelineGridItem> _gridItems = [];

  void _drawGrid(num interval) {
    // Draw the first grid item since it will have a different width than the
    // rest.
    final gridItem = TimelineGridItem(0, flameChartInset, 0);
    _gridItems.add(gridItem);
    add(gridItem);

    num left = flameChartInset;

    while (left + interval < _flameChartWidthWithInsets) {
      final timestamp = getTimestampForPosition(left + interval);
      final gridItem = TimelineGridItem(left, interval, timestamp);

      _gridItems.add(gridItem);
      add(gridItem);

      left += interval;
    }
  }

  void _clear() {
    clear();
    _gridItems.clear();
  }

  num getTimestampForPosition(num gridItemEnd) {
    return (gridItemEnd - flameChartInset) /
        _flameChartWidth *
        _frameDurationMs;
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

    if (log2NewZoomLevel == log2ZoomLevel) {
      // Don't modify the first grid item. This item will have a fixed left of
      // 0, width of [flameChartInset], and timestamp of '0.0 ms'.
      for (int i = 1; i < _gridItems.length; i++) {
        final currentItem = _gridItems[i];

        final newLeft = flameChartInset + zoomedGridIntervalPx * (i - 1);
        currentItem.update(newLeft, zoomedGridIntervalPx);
      }
    } else {
      _clear();
      _drawGrid(zoomedGridIntervalPx);
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

  num timestamp;
  num currentLeft;
  num currentWidth;

  /// The timestamp label for this grid item.
  CoreElement timestampLabel;

  /// The line for this grid item.
  CoreElement gridLine;

  void _initGridItem() {
    gridLine = div(c: 'grid-line');
    add(gridLine);

    timestampLabel = div(c: 'timestamp');
    add(timestampLabel);

    update(currentLeft, currentWidth);
  }

  void update(num left, num width) {
    currentLeft = left;
    currentWidth = width;

    element.style
      ..left = '${left}px'
      ..width = '${width}px';

    // Update [gridLine] position.
    gridLine.element.style.left = '${width - gridLineWidth}px';

    // Update [timestampLabel] position and text.
    timestampLabel.element.style
      ..left = '${timestampPadding}px'
      ..width = '${width - 2 * timestampPadding}px';
    timestampLabel.text =
        msAsText(timestamp, fractionDigits: timestamp == 0 ? 1 : 3);
  }
}
