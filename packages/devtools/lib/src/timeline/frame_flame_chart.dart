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
  }

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
      _render(frame);
    }
  }

  void _render(TimelineFrame frame) {
    const int leftIndent = 70;
    const int rowHeight = 25;
    const int sectionSpacing = 15;

    // 16,666 microseconds / frame will achieve a frame rate of 60 FPS.
    const double targetMicrosPerFrame = 1000 * 1000 / 60.0;

    /// Pixels per microsecond in order to fit a single frame in 1500px.
    ///
    /// For the whole frame to fit in 1500px at this drawing ratio, the frame
    /// duration must be [targetMicrosPerFrame] or less. 1500px is arbitrary.
    const double pixelsPerMicro = 1500 / targetMicrosPerFrame;

    final int frameStartOffset = frame.startTime;

    final cpuSectionHeight =
        frame.cpuEventFlow.depth * rowHeight + sectionSpacing;
    final gpuSectionHeight = frame.gpuEventFlow.depth * rowHeight;
    final flameChartWidth = max(
        element.clientWidth,
        leftIndent +
            (frame.gpuEventFlow.endTime - frame.cpuEventFlow.startTime) *
                pixelsPerMicro);

    void drawRecursively(TimelineEvent event, int row, CoreElement section) {
      final double startPx =
          (event.startTime - frameStartOffset) * pixelsPerMicro;
      final double endPx = (event.endTime - frameStartOffset) * pixelsPerMicro;

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
      final section = div(c: 'flame-chart-section');
      add(section);

      section.element.style
        ..height = '${cpuSectionHeight}px'
        ..width = '${flameChartWidth}px'
        ..backgroundColor = colorToCss(cpuSectionBackground);

      final sectionTitle = div(text: 'CPU', c: 'flame-chart-item');
      sectionTitle.element.style
        ..background = colorToCss(mainCpuColor)
        ..fontWeight = 'bold'
        ..left = '0'
        ..top = '0';
      section.add(sectionTitle);

      drawRecursively(frame.cpuEventFlow, 0, section);
    }

    void drawGpuEvents() {
      final section = div(c: 'flame-chart-section');
      add(section);

      section.element.style
        ..height = '${gpuSectionHeight}px'
        ..width = '${flameChartWidth}px'
        ..top = '${cpuSectionHeight}px';

      final sectionTitle = div(text: 'GPU', c: 'flame-chart-item');
      sectionTitle.element.style
        ..background = colorToCss(mainGpuColor)
        ..fontWeight = 'bold'
        ..left = '0'
        ..top = '0';
      section.add(sectionTitle);

      drawRecursively(frame.gpuEventFlow, 0, section);
    }

    drawCpuEvents();
    drawGpuEvents();
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
}
