// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';
import 'dart:math';

import '../ui/drag_scroll.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import 'timeline.dart';
import 'timeline_protocol.dart';

// TODO(kenzie): implement zoom functionality.

// Switch this flag to true to dump the frame event trace to console.
bool _debugEventTrace = false;

// Amber 50 color palette from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const cpuColorPalette = [
  Color(0xFFFFECB3),
  Color(0xFFFFE082),
  Color(0xFFFFD54F),
  mainCpuColor,
];

// Light Green 50 color palette from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const gpuColorPalette = [
  Color(0xFFDCEDC8),
  Color(0xFFC5E1A5),
  Color(0xFFAED581),
  mainGpuColor,
];

const cpuSectionBackground = Color(0xFFF9F9F9);
const gpuSectionBackground = Color(0xFFF3F3F3);

class FrameFlameChart extends CoreElement {
  FrameFlameChart() : super('div') {
    flex();
    layoutVertical();
    element.style
      ..backgroundColor = colorToCss(gpuSectionBackground)
      ..position = 'relative'
      ..marginTop = '4px'
      ..overflow = 'hidden';

    enableDragScrolling(this);
    element.onMouseMove.listen((MouseEvent e) => _handleMouseMove(e));
    element.onMouseWheel.listen((WheelEvent e) => _handleMouseWheel(e));
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

  num _zoomLevel = 1;
  num _minZoomLevel;

  // Throttling the zoomUnit makes the scrolling smoother.
  num get _zoomUnit {
    if (_zoomLevel <= 1) {
      return .01;
    } else if (_zoomLevel <= 1.05) {
      return .02;
    } else if (_zoomLevel <= 1.2) {
      return .04;
    } else if (_zoomLevel <= 1.3) {
      return .06;
    } else if (_zoomLevel < 3) {
      return .1;
    } else {
      return .2;
    }
  }

  num currentMouseX;
  num currentMouseY;
  num currentScrollWidth;
  num currentScrollTop = 0;
  num currentScrollLeft = 0;

  TimelineFrame frame;
  CoreElement sectionTitles;
  CoreElement flameChart;
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
    this.frame = frame;

    clear();

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

  void _render({bool reRender = false}) {
    const int leftIndent = 70;
    const int rowHeight = 25;
    const int sectionSpacing = 15;

    final double pixelsPerMicroWithZoom = pixelsPerMicro * _zoomLevel;

    final int frameStartOffset = frame.startTime;

    final cpuSectionHeight =
        frame.cpuEventFlow.depth * rowHeight + sectionSpacing;
    final gpuSectionHeight = frame.gpuEventFlow.depth * rowHeight;

    CoreElement cpuSection;
    CoreElement gpuSection;

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
        leftIndent + startPx.round(),
        (endPx - startPx).round(),
        row * rowHeight,
        section,
      );

      for (TimelineEvent child in event.children) {
        drawRecursively(child, row + 1, section);
      }
    }

    void drawCpuEvents() {
      cpuSection = div(c: 'flame-chart-section');
      add(cpuSection);

      cpuSection.element.style
        ..height = '${cpuSectionHeight}px'
        ..backgroundColor = colorToCss(cpuSectionBackground);

      final sectionTitle = div(text: 'CPU', c: 'flame-chart-item');
      sectionTitle.element.style
        ..background = colorToCss(mainCpuColor)
        ..fontWeight = 'bold'
        ..left = '0'
        ..top = '0';
      cpuSection.add(sectionTitle);

      drawRecursively(frame.cpuEventFlow, 0, cpuSection);
    }

    void drawGpuEvents() {
      gpuSection = div(c: 'flame-chart-section');
      add(gpuSection);

      gpuSection.element.style
        ..height = '${gpuSectionHeight}px'
        ..top = '${cpuSectionHeight}px';

      final sectionTitle = div(text: 'GPU', c: 'flame-chart-item');
      sectionTitle.element.style
        ..background = colorToCss(mainGpuColor)
        ..fontWeight = 'bold'
        ..left = '0'
        ..top = '0';
      gpuSection.add(sectionTitle);

      drawRecursively(frame.gpuEventFlow, 0, gpuSection);
    }

    drawCpuEvents();
    drawGpuEvents();

    final num scrollWidth = element.scrollWidth;

    // Set the section widths to [scrollWidth], as this should be the max width
    // we need for the flame chart.
    cpuSection.element.style.width = '${scrollWidth}px';
    gpuSection.element.style.width = '${scrollWidth}px';

    if (reRender) {
      // If we are re-rendering, we need to calculate and set our scroll position.
      final scrollLeft = scrollWidth *
          (currentMouseX + currentScrollLeft) /
          currentScrollWidth -
          currentMouseX;
      element.scrollLeft = scrollLeft.round();

      // Maintain the current vertical scrolling position.
      element.scrollTop = currentScrollTop;
    } else {
      // This is the initial render. Calculate our minimum zoom level.
      if (element.clientWidth == scrollWidth) {
        // If the entire flame chart fits on the screen, we have no need to zoom
        // out further.
        _minZoomLevel = 1;
      } else {
        // Multiply by .75 to account for rounding in drawing calculations. This
        // way the entire frame should fit on the screen at minimum zoom level.
        _minZoomLevel = min(element.clientWidth / scrollWidth * .75, 1);
      }
    }
  }

  void _reRender() {
    clear();
    // Reset the color offsets so that the chart coloring stays consistent on
    // re-rendering.
    _cpuColorOffset = 0;
    _gpuColorOffset = 0;
    _render(reRender: true);
  }

  void _drawFlameChartItem(
      TimelineEvent event, int left, int width, int top, CoreElement section) {
    final item = Element.div()..className = 'flame-chart-item';
    final labelWrapper = Element.div()
      ..className = 'flame-chart-item-label-wrapper';
    labelWrapper.append(Element.span()
      ..text = event.name
      ..className = 'flame-chart-item-label');
    item.append(labelWrapper);
    final style = item.style;
    style.background = event.isCpuEvent
        ? colorToCss(nextCpuColor())
        : colorToCss(nextGpuColor());
    style.left = '${left}px';
    if (width != null) {
      style.width = '${width}px';
      // This is critical to avoid having labels overflow the items boundaries.
      // For some reason, overflow:hidden does not play well with
      // position: sticky; so we have to implement this way.
      labelWrapper.style.maxWidth = '${width}px';
    }
    style.top = '${top}px';
    section.element.append(item);
  }

  void _handleMouseMove(MouseEvent e) {
    // Subtract offsets so that [currentMouseX] and [currentMouseY] reflect the
    // (x, y) coordinates within the flame chart.
    currentMouseX = e.client.x - element.offsetLeft;
    currentMouseY = e.client.y - element.offsetTop;

    // Store current scroll values for re-calculating scroll location on zoom.
    currentScrollTop = element.scrollTop;
    currentScrollLeft = element.scrollLeft;
    currentScrollWidth = element.scrollWidth;
  }

  void _handleMouseWheel(WheelEvent e) {
    e.preventDefault();

    if (e.deltaY.abs() > e.deltaX.abs()) {
      _handleZoom(e.deltaY);
    } else if (e.deltaX.abs() > e.deltaY.abs()) {
      // Manually perform horizontal scrolling.
      element.scrollLeft += e.deltaX;
      currentScrollLeft = element.scrollLeft;
    }
  }

  void _handleZoom(num deltaY) {
    if (deltaY > -0.0) {
      _zoomIn();
    } else if (deltaY < -0.0) {
      _zoomOut();
    }
  }

  void _zoomIn() {
    if (_zoomLevel >= 20) {
      // Already at max zoom level. Do nothing.
    } else if (frame != null) {
      _zoomLevel += _zoomUnit;
      _reRender();
    }
  }

  void _zoomOut() {
    if (_zoomLevel <= _minZoomLevel) {
      // Already at min zoom level. Do nothing.
    } else if (frame != null) {
      _zoomLevel -= _zoomUnit;
      _reRender();
    }
  }
}
