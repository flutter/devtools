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

  void updateFrameData(TimelineFrame frame) {
    this.frame = frame;

    clear();

    // TODO(kenzie): Sometimes we see a dump of the event trace that does not
    //  match what we draw in the flame chart. Fix this.
    if (_debugEventTrace && frame != null) {
      final StringBuffer buf = new StringBuffer();
      buf.writeln('CPU:');
      for (TimelineEvent event in frame.cpuEvents) {
        event.format(buf, '  ');
      }
      buf.writeln('GPU:');
      for (TimelineEvent event in frame.gpuEvents) {
        event.format(buf, '  ');
      }
      print(buf.toString());
    }

    if (frame != null) {
      _render(frame);
    }
  }

  void _render(TimelineFrame frame) {
    const int leftIndent = 60;
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
      final CoreElement sectionTitle = div(text: 'CPU', c: 'timeline-title');
      sectionTitle.element.style.left = '0';
      sectionTitle.element.style.top = '0';
      add(sectionTitle);

      maxRow = row;

      for (TimelineEvent event in frame.cpuEvents) {
        drawRecursively(event, row);
      }

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

      for (TimelineEvent event in frame.gpuEvents) {
        drawRecursively(event, row);
      }

      row = maxRow;

      row++;
    }

    drawCpuEvents();
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
