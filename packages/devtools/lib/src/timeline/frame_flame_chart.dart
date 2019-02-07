// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';
import 'timeline_protocol.dart';

// TODO(kenzie): implement zoom functionality.

// Switch this flag to true to dump the frame event trace to console.
bool _debugEventTrace = false;

class FrameFlameChart extends CoreElement {
  FrameFlameChart() : super('div') {
    flex();
    clazz('frame-timeline');
  }

  TimelineFrame frame;
  CoreElement sectionTitles;
  CoreElement flameChart;

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
    const int leftIndent = 80;
    const int rowHeight = 25;

    // TODO(kenzie): re-write this scale logic.
    const double microsPerFrame = 1000 * 1000 / 60.0;
    const double pxPerMicro = microsPerFrame / 1000.0;

    int row = 0;

    final int microsAdjust = frame.startTime;

    int maxRow = 0;

    void drawRecursively(TimelineEvent event, int row) {
      final double start = (event.startTime - microsAdjust) / pxPerMicro;
      final double end =
          (event.startTime - microsAdjust + event.duration) / pxPerMicro;

      _drawFlameChartItem(
        event,
        leftIndent + start.round(),
        (end - start).round(),
        row * rowHeight,
      );

      if (row > maxRow) {
        maxRow = row;
      }

      for (TimelineEvent child in event.children) {
        drawRecursively(child, row + 1);
      }
    }

    void drawCpuEvents() {
      final int sectionTop = row * rowHeight;
      final CoreElement sectionTitle = div(text: 'CPU', c: 'timeline-title');
      sectionTitle.element.style.left = '0';
      sectionTitle.element.style.top = '${sectionTop}px';
      add(sectionTitle);

      maxRow = row;

      drawRecursively(frame.cpuEventFlow, row);

      row = maxRow;

      row++;
    }

    void drawGpuEvents() {
      final int sectionTop = row * rowHeight;
      final CoreElement sectionTitle = div(text: 'GPU', c: 'timeline-title');
      sectionTitle.element.style.left = '0';
      sectionTitle.element.style.top = '${sectionTop}px';
      add(sectionTitle);

      maxRow = row;

      drawRecursively(frame.gpuEventFlow, row);

      row = maxRow;

      row++;
    }

    drawCpuEvents();

    // TODO(kenzie): improve this by adding a spacer div instead of just
    // increasing the row. Do this once each section is in its own container.
    // Add an additional row for spacing between CPU and GPU events.
    row++;

    drawGpuEvents();
  }

  // TODO(kenzie): re-assess this drawing logic.
  void _drawFlameChartItem(TimelineEvent event, int left, int width, int top) {
    final CoreElement item = div(text: event.name, c: 'timeline-title');
    item.element.style.left = '${left}px';
    if (width != null) {
      item.element.style.width = '${width}px';
    }
    item.element.style.top = '${top}px';
    add(item);
  }
}
