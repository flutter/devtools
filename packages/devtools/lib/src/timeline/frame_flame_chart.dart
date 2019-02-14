// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:math';

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

final StreamController<FlameChartItem> _selectedFlameChartItemController =
    StreamController<FlameChartItem>.broadcast();

Stream<FlameChartItem> get onSelectedFlameChartItem =>
    _selectedFlameChartItemController.stream;

class FrameFlameChart extends CoreElement {
  FrameFlameChart() : super('div', classes: 'section-border') {
    flex();
    layoutVertical();
    element.style
      ..backgroundColor = colorToCss(gpuSectionBackground)
      ..position = 'relative'
      ..marginTop = '4px'
      ..overflow = 'hidden';

    enableDragScrolling(this);
    element.onMouseMove.listen(_handleMouseMove);
    element.onMouseWheel.listen(_handleMouseWheel);

    onSelectedFlameChartItem.listen((FlameChartItem item) {
      // Unselect the previously selected item.
      if (_selectedItem != null) {
        _selectedItem.setSelected(false);
      }

      // Select the new item.
      item.setSelected(true);
      _selectedItem = item;
    });
  }

  /// Target maximum microseconds per frame.
  ///
  /// 16,666 microseconds per frame will achieve a frame rate of 60 FPS.
  static const double targetMicrosPerFrame = 1000 * 1000 / 60.0;

  /// Pixels per microsecond in order to fit a single frame in 1500px.
  ///
  /// For the whole frame to fit in 1500px at this drawing ratio, the frame
  /// duration must be [targetMicrosPerFrame] or less. 1500px is arbitrary.
  static const double pixelsPerMicro = 1500 / targetMicrosPerFrame;

  /// Multiplier that accounts for rounding in drawing calculations.
  ///
  /// When the [_minZoomLevel] is calculated, rounding in drawing calculations
  /// can lead to a slightly higher value than we want. Multiplying the
  /// calculated [_minZoomLevel] by this multiplier will ensure the entire flame
  /// chart is drawn within view at minimum zoom level.
  static const num minZoomMultiplier = 0.75;

  static const padding = 2;

  /// All flame chart items currently drawn on the chart.
  final List<FlameChartItem> _chartItems = [];

  /// Maximum zoom level we should allow.
  ///
  /// Arbitrary large number to accommodate spacing for some of the shortest
  /// events when zoomed in to [_maxZoomLevel].
  final num _maxZoomLevel = 120;
  num _zoomLevel = 1;
  num _minZoomLevel;

  num get _zoomMultiplier => _zoomLevel * 0.075;

  num _currentMouseX;
  num _currentScrollWidth;
  num _currentScrollLeft = 0;

  FlameChartItem _selectedItem;

  TimelineFrame _frame;
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
    _chartItems.clear();
  }

  void _render() {
    const int rowHeight = 25;
    const int sectionSpacing = 15;

    final double pixelsPerMicroWithZoom = pixelsPerMicro * _zoomLevel;
    final int frameStartOffset = _frame.startTime;
    final cpuSectionHeight =
        _frame.cpuEventFlow.depth * rowHeight + sectionSpacing;
    final gpuSectionHeight = _frame.gpuEventFlow.depth * rowHeight;

    void drawRecursively(TimelineEvent event, int row, CoreElement section) {
      final double startPx =
          (event.startTime - frameStartOffset) * pixelsPerMicroWithZoom;
      final double endPx =
          (event.endTime - frameStartOffset) * pixelsPerMicroWithZoom;

      _drawFlameChartItem(
        event,
        // TODO(kenzie): technically we will want to round to fraction of a px
        // for high dpi devices where 1 logical pixel may equal 2 physical
        // pixels, etc.
        startPx.round() + padding,
        (endPx - startPx).round(),
        row * rowHeight + padding,
        section,
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
        ..backgroundColor = colorToCss(cpuSectionBackground);

      final sectionTitle = div(text: 'CPU', c: 'flame-chart-item');
      sectionTitle.element.style
        ..background = colorToCss(mainCpuColor)
        ..fontWeight = 'bold'
        ..left = '${padding}px'
        ..top = '${padding}px';
      _cpuSection.add(sectionTitle);

      drawRecursively(_frame.cpuEventFlow, 0, _cpuSection);
    }

    void drawGpuEvents() {
      _gpuSection = div(c: 'flame-chart-section');
      add(_gpuSection);

      _gpuSection.element.style
        ..height = '${gpuSectionHeight}px'
        ..top = '${cpuSectionHeight}px';

      final sectionTitle = div(text: 'GPU', c: 'flame-chart-item');
      sectionTitle.element.style
        ..background = colorToCss(mainGpuColor)
        ..fontWeight = 'bold'
        ..left = '${padding}px'
        ..top = '${padding}px';
      _gpuSection.add(sectionTitle);

      drawRecursively(_frame.gpuEventFlow, 0, _gpuSection);
    }

    drawCpuEvents();
    drawGpuEvents();
    _setSectionWidths();

    // Calculate our [_minZoomLevel]. At [_zoomLevel] = [_minZoomLevel], the
    // entire flame chart should fit on the screen.
    if (element.clientWidth == element.scrollWidth) {
      _minZoomLevel = 1;
    } else {
      _minZoomLevel =
          min(element.clientWidth / element.scrollWidth * minZoomMultiplier, 1);
    }
  }

  void _drawFlameChartItem(
    TimelineEvent event,
    int left,
    int width,
    int top,
    CoreElement section,
  ) {
    final item = FlameChartItem(
      event,
      left,
      width,
      top,
      event.isCpuEvent ? nextCpuColor() : nextGpuColor(),
    );

    _chartItems.add(item);
    section.element.append(item.e);
  }

  void _setSectionWidths() {
    final width = getFlameChartWidth();
    _cpuSection.element.style.width = '${width}px';
    _gpuSection.element.style.width = '${width}px';
  }

  num getFlameChartWidth() {
    int maxRight = 0;
    for (FlameChartItem item in _chartItems) {
      if ((item.currentLeft + item.currentWidth) > maxRight) {
        maxRight = item.currentLeft + item.currentWidth;
      }
    }
    return maxRight;
  }

  void _handleMouseMove(MouseEvent e) {
    // Subtract offset so that [currentMouseX] reflects the x coordinate within
    // the bounds of the flame chart.
    _currentMouseX = e.client.x - element.offsetLeft;

    // Store current scroll values for re-calculating scroll location on zoom.
    _currentScrollLeft = element.scrollLeft;
    _currentScrollWidth = element.scrollWidth;
  }

  void _handleMouseWheel(WheelEvent e) {
    e.preventDefault();

    if (e.deltaY.abs() > e.deltaX.abs()) {
      _handleZoom(e.deltaY);
    } else if (e.deltaX.abs() > e.deltaY.abs()) {
      // Manually perform horizontal scrolling.
      element.scrollLeft += e.deltaX;
      _currentScrollLeft = element.scrollLeft;
    }
  }

  void _handleZoom(num deltaY) {
    // TODO(kenzie): use deltaY to calculate [_zoomMultiplier].
    if (deltaY > -0.0) {
      _zoomIn();
    } else if (deltaY < -0.0) {
      _zoomOut();
    }
  }

  void _zoomIn() {
    if (_zoomLevel >= _maxZoomLevel) {
      // Already at max zoom level. Do nothing.
    } else if (_frame != null) {
      _zoomLevel += _zoomMultiplier;
      _updateChartForZoom();
    }
  }

  void _zoomOut() {
    if (_zoomLevel <= _minZoomLevel) {
      // Already at min zoom level. Do nothing.
    } else if (_frame != null) {
      _zoomLevel -= _zoomMultiplier;
      _updateChartForZoom();
    }
  }

  void _updateChartForZoom() {
    for (FlameChartItem item in _chartItems) {
      item.updateForZoomLevel(_zoomLevel);
    }
    _setSectionWidths();

    // Calculate and set our new horizontal scroll position.
    final scrollLeft = (element.scrollWidth *
                (_currentMouseX + _currentScrollLeft) /
                _currentScrollWidth -
            _currentMouseX)
        .round();
    element.scrollLeft = scrollLeft;

    // Update our current scroll values.
    _currentScrollLeft = element.scrollLeft;
    _currentScrollWidth = element.scrollWidth;
  }
}

class FlameChartItem {
  FlameChartItem(
    this._event,
    this._startingLeft,
    this._startingWidth,
    this._top,
    this._backgroundColor,
  ) {
    currentLeft = _startingLeft;
    currentWidth = _startingWidth;

    e = Element.div()..className = 'flame-chart-item';
    e.title = microsAsMsText(_event.duration);

    _labelWrapper = Element.div()..className = 'flame-chart-item-label-wrapper';
    _label = Element.span()
      ..text = _event.name
      ..className = 'flame-chart-item-label'
      ..style.color = colorToCss(defaultTextColor);
    _labelWrapper.append(_label);
    e.append(_labelWrapper);

    final style = e.style;
    style
      ..background = colorToCss(_backgroundColor)
      ..left = '${leftOffset + _startingLeft}px';
    if (_startingWidth != null) {
      style.width = '${_startingWidth}px';
      // This is critical to avoid having labels overflow the items boundaries.
      // For some reason, overflow:hidden does not play well with
      // position: sticky; so we have to implement this way.
      _labelWrapper.style.maxWidth = '${_startingWidth}px';
    }
    style.top = '${_top}px';

    // TODO(kenzie): make flame chart item appear selected.
    e.onClick.listen((e) => _selectedFlameChartItemController.add(this));
  }

  /// Offset to account for section titles (i.e 'CPU' and 'GPU').
  static const leftOffset = 70;

  static const defaultTextColor = Color(0xFF000000);
  static const selectedTextColor = Color(0xFFFFFFFF);

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

  void updateForZoomLevel(num zoom) {
    currentLeft = leftOffset + (_startingLeft * zoom).round();
    currentWidth = (_startingWidth * zoom).round();
    e.style.left = '${currentLeft}px';
    if (_startingWidth != null) {
      e.style.width = '${currentWidth}px';
      _labelWrapper.style.maxWidth = '${currentWidth}px';
    }
  }

  void setSelected(bool selected) {
    e.style.backgroundColor =
        colorToCss(selected ? selectedColor : _backgroundColor);
    _label.style.color =
        colorToCss(selected ? selectedTextColor : defaultTextColor);
  }
}
