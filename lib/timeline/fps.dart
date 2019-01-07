// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../charts/charts.dart';
import '../ui/elements.dart';
import '../ui/flutter_html_shim.dart';
import '../vm_service_wrapper.dart';
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

      final String color = _isSlowFrame(frame)
          ? colorToCss(slowFrameColor)
          : colorToCss(normalFrameColor);
      final String tooltip = _isSlowFrame(frame)
          ? 'This frame took ${frame.elapsedMs}ms to render, which can cause '
              'frame rate to drop below 60 FPS.'
          : 'This frame took ${frame.elapsedMs}ms to render.';
      svgElements.add('<rect x="$x" y="${dim.y - height}" rx="1" ry="1" '
          'width="${2 * units}" height="$height" '
          'style="fill:$color"><title>$tooltip</title></rect>');

      if (frame.frameGroupStart) {
        final double lineX = x - (units / 2);
        svgElements.add('<line x1="$lineX" y1="0" x2="$lineX" y2="${dim.y}" '
            'stroke-width="0.5" stroke-dasharray="4 4" stroke="#ddd"/>');
      }
    }

    chartElement.setInnerHtml('''
     <svg viewBox="0 0 ${dim.x} ${dim.y}">
     ${svgElements.join('\n')}
     </svg>
     ''');
  }

  bool _isSlowFrame(FrameInfo frame) {
    return frame.elapsedMs > FrameInfo.kTargetMaxFrameTimeMs;
  }
}

class FramesTracker {
  FramesTracker(this.service) {
    service.onExtensionEvent.listen((Event e) {
      if (e.extensionKind == 'Flutter.Frame') {
        final ExtensionData data = e.extensionData;
        addSample(FrameInfo.from(data.data));
      }
    });
  }

  static const int kMaxFrames = 60;

  VmServiceWrapper service;
  final StreamController<Null> _changeController =
      new StreamController<Null>.broadcast();
  List<FrameInfo> samples = <FrameInfo>[];

  bool get hasConnection => service != null;

  Stream<Null> get onChange => _changeController.stream;

  void start() {}

  void stop() {}

  void addSample(FrameInfo frame) {
    if (samples.isEmpty) {
      frame.frameGroupStart = true;
    } else {
      frame.calcFrameGroupStart(samples.last);
    }
    samples.add(frame);
    while (samples.length > kMaxFrames) {
      samples.removeAt(0);
    }
    _changeController.add(null);
  }

  FrameInfo get lastSample => samples.isEmpty ? null : samples.last;

  num calcRecentFPS() {
    int frameCount = 0;
    int usedFrames = 0;

    for (int i = samples.length - 1; i >= 0; i--) {
      final FrameInfo frame = samples[i];

      frameCount++;

      num frameTime = frame.elapsedMs;
      int requiredFrames =
          (frameTime / FrameInfo.kTargetMaxFrameTimeMs).round();
      frameTime -= requiredFrames * FrameInfo.kTargetMaxFrameTimeMs;
      if (frameTime > 0) {
        requiredFrames++;
      }
      usedFrames += requiredFrames;

      if (frame.frameGroupStart) {
        break;
      }
    }

    return 1000 * frameCount / (usedFrames * FrameInfo.kTargetMaxFrameTimeMs);
  }
}

class FrameInfo {
  FrameInfo(this.number, this.elapsedMs, this.startTimeMs);

  static const double kTargetMaxFrameTimeMs = 1000.0 / 60;

  static FrameInfo from(Map<dynamic, dynamic> data) {
    return new FrameInfo(
        data['number'], data['elapsed'] / 1000, data['startTime'] / 1000);
  }

  final int number;
  final num elapsedMs;
  final num startTimeMs;

  bool frameGroupStart = false;

  num get endTimeMs => startTimeMs + elapsedMs;

  void calcFrameGroupStart(FrameInfo previousFrame) {
    if (startTimeMs > (previousFrame.endTimeMs + kTargetMaxFrameTimeMs)) {
      frameGroupStart = true;
    }
  }

  @override
  String toString() => 'frame $number ${elapsedMs.toStringAsFixed(1)}ms';
}
