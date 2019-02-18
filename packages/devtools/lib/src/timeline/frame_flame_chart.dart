// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

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
    element.onMouseMove.listen(_handleMouseMove);
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
  final num _maxZoomLevel = 150;
  final _minZoomLevel = 1;
  num _zoomLevel = 1;

  num get _zoomMultiplier => _zoomLevel * 0.075;

  num _currentScrollWidth;
  num _currentScrollLeft = 0;
  num _currentMouseX = 0;

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
      // Do not round these values. Rounding the left could case us to have
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
        ..backgroundColor = colorToCss(cpuSectionBackground);

      final sectionTitle =
          div(text: 'CPU', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainCpuColor)
        ..left = '${padding}px'
        ..top = '${padding}px';
      _cpuSection.add(sectionTitle);

      drawRecursively(_frame.cpuEventFlow, 0, _cpuSection,
          includeDuration: true);
    }

    void drawGpuEvents() {
      _gpuSection = div(c: 'flame-chart-section');
      add(_gpuSection);

      _gpuSection.element.style
        ..height = '${gpuSectionHeight}px'
        ..top = '${cpuSectionHeight}px';

      final sectionTitle =
          div(text: 'GPU', c: 'flame-chart-item flame-chart-title');
      sectionTitle.element.style
        ..background = colorToCss(mainGpuColor)
        ..left = '${padding}px'
        ..top = '${padding}px';
      _gpuSection.add(sectionTitle);

      drawRecursively(_frame.gpuEventFlow, 0, _gpuSection,
          includeDuration: true);
    }

    drawCpuEvents();
    drawGpuEvents();
    _setSectionWidths();
    _currentScrollWidth = element.scrollWidth;
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
    // Add [flameChartInset] to account for spacing at the end of the chart.
    final width = getFlameChartWidth() + flameChartInset;
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
    assert(_frame != null);
    if (_zoomLevel == _maxZoomLevel) {
      // Already at max zoom level. Do nothing.
      return;
    }

    if (_zoomLevel + _zoomMultiplier <= _maxZoomLevel) {
      _zoomLevel += _zoomMultiplier;
    } else {
      _zoomLevel = _maxZoomLevel;
    }
    _updateChartForZoom();
  }

  void _zoomOut() {
    assert(_frame != null);
    if (_zoomLevel == _minZoomLevel) {
      // Already at min zoom level. Do nothing.
      return;
    }

    if (_zoomLevel - _zoomMultiplier >= _minZoomLevel) {
      _zoomLevel -= _zoomMultiplier;
    } else {
      _zoomLevel = _minZoomLevel;
    }
    _updateChartForZoom();
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
    this._backgroundColor, {
    bool includeDuration = false,
  }) {
    currentLeft = _startingLeft;
    currentWidth = _startingWidth;

    e = Element.div()..className = 'flame-chart-item';
    e.title = microsAsMsText(_event.duration);

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

    final style = e.style;
    style
      ..background = colorToCss(_backgroundColor)
      ..left = '${flameChartInset + _startingLeft}px';
    if (_startingWidth != null) {
      style.width = '${_startingWidth}px';
      // This is critical to avoid having labels overflow the items boundaries.
      // For some reason, overflow:hidden does not play well with
      // position: sticky; so we have to implement this way.
      _labelWrapper.style.maxWidth = '${_startingWidth}px';
    }
    style.top = '${_top}px';

    e.onClick.listen((e) {
      // Prevent clicks when the chart was being dragged.
      if (!_dragScroll.wasDragged) {
        _selectedFlameChartItemController.add(this);
      }
    });
  }

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

  Color get backgroundColor => _backgroundColor;

  void updateForZoomLevel(num zoom) {
    // Do not round these values. Rounding the left could case us to have
    // inaccurately placed events on the chart. Rounding the width could cause
    // us to lose very small events if the width rounds to zero.
    final newLeft = flameChartInset + _startingLeft * zoom;
    final newWidth = _startingWidth * zoom;

    e.style.left = '${newLeft}px';
    if (_startingWidth != null) {
      e.style.width = '${newWidth}px';
      _labelWrapper.style.maxWidth = '${newWidth}px';
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
