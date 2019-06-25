// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../ui/analytics.dart' as ga;
import '../ui/colors.dart';
import '../ui/drag_scroll.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

// TODO(kenzie): port all of this code to use flame_chart_canvas.dart.

final StreamController<FrameFlameChartItem>
    _selectedFrameFlameChartItemController =
    StreamController<FrameFlameChartItem>.broadcast();

Stream<FrameFlameChartItem> get onSelectedFrameFlameChartItem =>
    _selectedFrameFlameChartItemController.stream;

final DragScroll _dragScroll = DragScroll();

const _flameChartInset = 70;

class FrameEventsChart extends CoreElement {
  FrameEventsChart(this.timelineController)
      : super('div', classes: 'section-border flame-chart-container') {
    flex();
    layoutVertical();

    _dragScroll.enableDragScrolling(this);
    _initListeners();
  }

  static const padding = 2;
  static const int rowHeight = 25;
  static const int sectionSpacing = 15;

  final TimelineController timelineController;

  /// All flame chart items currently drawn on the chart.
  final List<FrameFlameChartItem> chartItems = [];

  /// Maximum scroll delta allowed for scrollwheel based zooming.
  ///
  /// This isn't really needed but is a reasonable for safety in case we
  /// aren't handling some mouse based scroll wheel behavior well, etc.
  final num maxScrollWheelDelta = 20;

  /// Maximum zoom level we should allow.
  ///
  /// Arbitrary large number to accommodate spacing for some of the shortest
  /// events when zoomed in to [_maxZoomLevel].
  final _maxZoomLevel = 150;
  final _minZoomLevel = 1;
  num zoomLevel = 1;

  num get _zoomMultiplier => zoomLevel * 0.003;

  // The DOM doesn't allow floating point scroll offsets so we track a
  // theoretical floating point scroll offset corresponding to the current
  // scroll offset to reduce floating point error when zooming.
  num floatingPointScrollLeft = 0;

  int _uiColorOffset = 0;

  int _gpuColorOffset = 0;

  FrameFlameChartItem selectedItem;

  TimelineGrid _timelineGrid;

  CoreElement _flameChart;

  CoreElement _timelineBackground;

  CoreElement _uiSection;

  CoreElement _gpuSection;

  void _initListeners() {
    element.onMouseWheel.listen(_handleMouseWheel);
    onSelectedFrameFlameChartItem.listen(_selectItem);
    timelineController.onSelectedFrame.listen((_) => update());
  }

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

  void _reset() {
    clear();
    element.scrollLeft = 0;
    element.scrollTop = 0;
    zoomLevel = 1;
    chartItems.clear();
    _uiColorOffset = 0;
    _gpuColorOffset = 0;
  }

  void update() {
    final frame = timelineController.timelineData.selectedFrame;
    _reset();

    if (frame != null) {
      hidden(false);
      _render(frame);
    }
  }

  void _render(TimelineFrame frame) {
    /// Pixels per microsecond in order to fit the entire frame in view.
    ///
    /// Subtract 2 * [sectionLabelOffset] to account for extra space at the
    /// beginning/end of the chart.
    final double pxPerMicro = (element.clientWidth - 2 * _flameChartInset) /
        frame.time.duration.inMicroseconds;

    final int frameStartOffset = frame.time.start.inMicroseconds;
    final uiSectionHeight =
        frame.uiEventFlow.depth * rowHeight + sectionSpacing;
    final gpuSectionHeight = frame.gpuEventFlow.depth * rowHeight;
    final flameChartHeight = 2 * rowHeight + uiSectionHeight + gpuSectionHeight;

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
        row * rowHeight + padding,
        section,
        includeDuration: includeDuration,
      );

      for (TimelineEvent child in event.children) {
        drawSubtree(child, row + 1, section);
      }
    }

    void drawTimelineBackground() {
      _timelineBackground = div(c: 'timeline-background')
        ..element.style.height = '${rowHeight}px';
      add(_timelineBackground);
    }

    void drawUiEvents() {
      _uiSection = div(c: 'flame-chart-section ui');
      _flameChart.add(_uiSection);

      _uiSection.element.style
        ..height = '${uiSectionHeight}px'
        ..top = '${rowHeight}px';

      final sectionTitle =
          div(text: 'UI', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainUiColor)
        ..left = '${padding}px'
        ..top = '${padding}px';
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
        ..top = '${rowHeight + uiSectionHeight}px';

      final sectionTitle =
          div(text: 'GPU', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainGpuColor)
        ..left = '${padding}px'
        ..top = '${padding}px';
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
      timelineController,
      event,
      left,
      width,
      top,
      event.isUiEvent ? nextUiColor() : nextGpuColor(),
      event.isUiEvent
          ? ThemedColor.fromSingleColor(Colors.black)
          : ThemedColor.fromSingleColor(contrastForegroundWhite),
      Colors.black,
      includeDuration: includeDuration,
    );
    chartItems.add(item);
    section.element.append(item.element);
  }

  void _setSectionWidths() {
    // Add 2 * [flameChartInset] to account for spacing at the beginning and end
    // of the chart.
    final width = getFlameChartWidth() + 2 * _flameChartInset;
    _flameChart.element.style.width = '${width}px';
    _timelineBackground.element.style.width = '${width}px';
    _uiSection.element.style.width = '${width}px';
    _gpuSection.element.style.width = '${width}px';
  }

  num getFlameChartWidth() {
    num maxRight = 0;
    for (FrameFlameChartItem item in chartItems) {
      if ((item.currentLeft + item.currentWidth) > maxRight) {
        maxRight = item.currentLeft + item.currentWidth;
      }
    }
    // Subtract [beginningInset] to account for spacing at the beginning of the
    // chart.
    return maxRight - _flameChartInset;
  }

  void _selectItem(FrameFlameChartItem item) {
    if (item == selectedItem) {
      return;
    }
    // Unselect the previously selected item.
    selectedItem?.setSelected(false);

    // Select the new item.
    item.setSelected(true);
    selectedItem = item;
  }

  void _handleMouseWheel(WheelEvent e) {
    e.preventDefault();

    if (e.deltaY.abs() >= e.deltaX.abs()) {
      final mouseX = e.client.x - element.getBoundingClientRect().left;
      _zoom(e.deltaY, mouseX);
    } else {
      // Manually perform horizontal scrolling.
      element.scrollLeft += e.deltaX.round();
    }
  }

  void _zoom(num deltaY, num mouseX) {
    assert(timelineController.timelineData.selectedFrame != null);

    deltaY = deltaY.clamp(-maxScrollWheelDelta, maxScrollWheelDelta);
    num newZoomLevel = zoomLevel + deltaY * _zoomMultiplier;
    newZoomLevel = newZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);

    if (newZoomLevel == zoomLevel) return;
    // Store current scroll values for re-calculating scroll location on zoom.
    num lastScrollLeft = element.scrollLeft;
    // Test whether the scroll offset has changed by more than rounding error
    // since the last time an exact scroll offset was calculated.
    if ((floatingPointScrollLeft - lastScrollLeft).abs() < 0.5) {
      lastScrollLeft = floatingPointScrollLeft;
    }
    // Position in the zoomable coordinate space that we want to keep fixed.
    final num fixedX = mouseX + lastScrollLeft - _flameChartInset;
    // Calculate and set our new horizontal scroll position.
    if (fixedX >= 0) {
      floatingPointScrollLeft =
          fixedX * newZoomLevel / zoomLevel + _flameChartInset - mouseX;
    } else {
      // No need to transform as we are in the fixed portion of the window.
      floatingPointScrollLeft = lastScrollLeft;
    }
    zoomLevel = newZoomLevel;

    _updateChartForZoom();
  }

  void _updateChartForZoom() {
    for (FrameFlameChartItem item in chartItems) {
      item.updateHorizontalPosition(zoom: zoomLevel);
    }
    _setSectionWidths();
    _timelineGrid.updateForZoom(zoomLevel, getFlameChartWidth());
    element.scrollLeft = math.max(0, floatingPointScrollLeft.round());
  }
}

class FrameFlameChartItem {
  FrameFlameChartItem(
    this.timelineController,
    this._event,
    this.startingLeft,
    this.startingWidth,
    this.top,
    this.backgroundColor,
    this.defaultTextColor,
    this.selectedTextColor, {
    this.includeDuration = false,
  }) {
    element = Element.div()..className = 'flame-chart-item';
    _labelWrapper = Element.div()..className = 'flame-chart-item-label-wrapper';

    itemLabel = Element.span()
      ..className = 'flame-chart-item-label'
      ..style.color = colorToCss(defaultTextColor);
    _labelWrapper.append(itemLabel);
    element.append(_labelWrapper);

    element.style
      ..background = colorToCss(backgroundColor)
      ..top = '${top}px';
    updateHorizontalPosition(zoom: 1);

    setText();
    setOnClick();
  }

  /// Pixels of padding to place on the right side of the label to ensure label
  /// text does not get too close to the right hand size of each div.
  static const labelPaddingRight = 4;

  static const selectedBorderColor = ThemedColor(
    Color(0x5A1B1F23),
    Color(0x5A1B1F23),
  );

  TimelineEvent get event => _event;

  final TimelineEvent _event;

  final bool includeDuration;

  final TimelineController timelineController;

  /// Left value for the flame chart item at zoom level 1.
  final num startingLeft;

  /// Width value for the flame chart item at zoom level 1;
  final num startingWidth;

  /// Top position for the flame chart item.
  final num top;

  final Color backgroundColor;

  final Color defaultTextColor;

  final Color selectedTextColor;

  Element element;

  Element itemLabel;

  Element _labelWrapper;

  double currentLeft;

  double currentWidth;

  void setText() {
    final durationText = msText(event.time.duration);

    String title = _event.name;
    element.title = '$title ($durationText)';

    if (includeDuration) {
      title = '$title ($durationText)';
    }

    itemLabel.text = title;
  }

  void setOnClick() {
    element.onClick.listen((e) {
      // Prevent clicks when the chart was being dragged.
      if (!_dragScroll.wasDragged) {
        // Add to [_selectedFrameFlameChartItemController] in addition to
        // calling [timelineController.selectTimelineEvent] because we need to
        // pass the flame chart item colors to [EventDetails].
        _selectedFrameFlameChartItemController.add(this);
        timelineController.selectTimelineEvent(event);
        ga.select(
          ga.timeline,
          event.isGpuEvent ? ga.timelineFlameGpu : ga.timelineFlameUi,
          event.time.duration.inMicroseconds, // inMilliseconds loses precision
        );
      }
    });
  }

  void updateHorizontalPosition({@required num zoom}) {
    // Do not round these values. Rounding the left could cause us to have
    // inaccurately placed events on the chart. Rounding the width could cause
    // us to lose very small events if the width rounds to zero.
    final newLeft = _flameChartInset + startingLeft * zoom;
    final newWidth = startingWidth * zoom;

    element.style.left = '${newLeft}px';
    if (startingWidth != null) {
      element.style.width = '${newWidth}px';
      _labelWrapper.style.maxWidth =
          '${math.max(0, newWidth - labelPaddingRight)}px';
    }
    currentLeft = newLeft;
    currentWidth = newWidth;
  }

  void setSelected(bool selected) {
    element.style
      ..backgroundColor =
          colorToCss(selected ? selectedFlameChartItemColor : backgroundColor)
      ..border = selected ? '1px solid' : 'none'
      ..borderColor = colorToCss(selectedBorderColor);
    itemLabel.style.color =
        colorToCss(selected ? selectedTextColor : defaultTextColor);
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
