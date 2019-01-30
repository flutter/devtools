// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import '../charts/charts.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import 'frame_rendering.dart';
import 'timeline.dart';

class FramesChart extends LineChart<FramesTracker> {
  FramesChart(CoreElement parent) : super(parent, classes: 'perf-chart') {
    fpsLabel = parent.add(div(c: 'perf-label top-left'));

    lastFrameLabel = parent.add(div(c: 'perf-label top-right')
      ..tooltip = 'Rendering time of latest frame.');
  }

  CoreElement fpsLabel;
  CoreElement lastFrameLabel;

  @override
  void update(FramesTracker data) {
    if (dim == null) {
      return;
    }

    fpsLabel.text = '${data.calcRecentFPS().round()} frames per second';
    final FrameInfo lastFrame = data.lastSample;
    lastFrameLabel.setInnerHtml('frame ${lastFrame.number} • '
        '${lastFrame.elapsedMs.toStringAsFixed(1)}ms');

    // re-render the svg
    const num msHeight = 2 * FrameInfo.kTargetMaxFrameTimeMs;
    const num halfFrameHeight = FrameInfo.kTargetMaxFrameTimeMs / 2;
    final num pixPerMs = dim.y / msHeight;
    final double units = dim.x / (3 * FramesTracker.kMaxFrames);

    final List<String> svgElements = <String>[];
    final List<FrameInfo> samples = data.samples;

    for (int i = 3; i > 0; i--) {
      final num y = i * halfFrameHeight * pixPerMs;
      final String dashed = i == 2 ? '' : 'stroke-dasharray="10 5" ';
      svgElements.add('<line x1="0" y1="$y" x2="${dim.x}" y2="$y" '
          'stroke-width="0.5" stroke="#ddd" $dashed/>');
    }

    double x = dim.x.toDouble();

    for (int i = samples.length - 1; i >= 0; i--) {
      final FrameInfo frame = samples[i];
      final num height = math.min(dim.y, frame.elapsedMs * pixPerMs);
      x -= 3 * units;

      final Color color =
      _isSlowFrame(frame) ? slowFrameColor : normalFrameColor;
      final String tooltip = _isSlowFrame(frame)
          ? 'This frame took ${frame.elapsedMs}ms to render, which can cause '
          'frame rate to drop below 60 FPS.'
          : 'This frame took ${frame.elapsedMs}ms to render.';
      svgElements.add('<rect x="$x" y="${dim.y - height}" rx="1" ry="1" '
          'width="${2 * units}" height="$height" '
          'style="fill:${colorToCss(color)}"><title>$tooltip</title></rect>');

      if (frame.frameGroupStart) {
        final double lineX = x - (units / 2);
        svgElements.add('<line x1="$lineX" y1="0" x2="$lineX" y2="${dim.y}" '
            'stroke-width="0.5" stroke-dasharray="4 4" stroke="#ddd"/>');
      }
    }

    chartElement.setInnerHtml('''
     <svg viewBox="0 0 ${dim.x} ${LineChart.fixedHeight}">
     ${svgElements.join('\n')}
     </svg>
     ''');
  }

  bool _isSlowFrame(FrameInfo frame) {
    return frame.elapsedMs > FrameInfo.kTargetMaxFrameTimeMs;
  }
}
