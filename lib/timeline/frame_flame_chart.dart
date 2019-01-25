// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';
import '../ui/primer.dart';
import 'timeline_protocol.dart';

// Switch this flag to true to dump the frame event trace to console.
bool _debugEventTrace = false;

class FrameFlameChart extends CoreElement {
  FrameFlameChart() : super('div') {
    layoutVertical();
    flex();

    // TODO(devoncarew): listen to tab changes
    content = div(c: 'frame-timeline')..flex();

    final PTabNav tabNav = PTabNav(<PTabNavTab>[
      PTabNavTab('Frame timeline'),
      PTabNavTab('Widget build info'),
      PTabNavTab('Skia picture'),
    ]);

    add(<CoreElement>[
      tabNav,
      content,
    ]);

    content.element.style.whiteSpace = 'pre';
    content.element.style.overflow = 'scroll';
  }

  TimelineFrameData data;
  CoreElement content;

  void updateData(TimelineFrameData data) {
    this.data = data;

    content.clear();

    if (_debugEventTrace && data != null) {
      final StringBuffer buf = new StringBuffer();
      for (TimelineThread thread in data.threads) {
        buf.writeln('${thread.name}:');
        for (TimelineThreadEvent event in data.events) {
          if (event.threadId == thread.threadId) {
            event.format(buf, '  ');
          }
        }
      }
      print(buf.toString());
    }

    if (data != null) {
      _render(data);
    }
  }

  void _render(TimelineFrameData data) {
    const int leftIndent = 130;
    const int rowHeight = 25;

    const double microsPerFrame = 1000 * 1000 / 60.0;
    const double pxPerMicro = microsPerFrame / 1000.0;

    int row = 0;

    final int microsAdjust = data.frame.startMicros;

    int maxRow = 0;

    void drawRecursively(TimelineThreadEvent event, int row) {
      if (!event.wellFormed) {
        print('event not well formed: $event');
        return;
      }

      final double start = (event.startMicros - microsAdjust) / pxPerMicro;
      final double end =
          (event.startMicros - microsAdjust + event.durationMicros) /
              pxPerMicro;

      _createPosition(event.name, leftIndent + start.round(),
          (end - start).round(), row * rowHeight);

      if (row > maxRow) {
        maxRow = row;
      }

      for (TimelineThreadEvent child in event.children) {
        drawRecursively(child, row + 1);
      }
    }

    // TODO: investigate if this try/catch is necessary.
    try {
      for (TimelineThread thread in data.threads) {
        _createPosition(thread.name, 0, null, row * rowHeight);

        maxRow = row;

        for (TimelineThreadEvent event in data.eventsForThread(thread)) {
          drawRecursively(event, row);
        }

        row = maxRow;

        row++;
      }
    } catch (e, st) {
      print('$e\n$st');
    }
  }

  void _createPosition(String name, int left, int width, int top) {
    final CoreElement item = div(text: name, c: 'timeline-title');
    item.element.style.left = '${left}px';
    if (width != null) {
      item.element.style.width = '${width}px';
    }
    item.element.style.top = '${top}px';
    content.add(item);
  }
}
