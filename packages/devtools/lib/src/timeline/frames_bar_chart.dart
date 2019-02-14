// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../utils.dart';
import 'timeline.dart';
import 'timeline_controller.dart';
import 'timeline_protocol.dart';

class FramesBarChart extends CoreElement {
  FramesBarChart(TimelineController timelineController)
      : super('div', classes: 'timeline-frames section-border') {
    layoutHorizontal();
    element.style
      ..alignItems = 'flex-end'
      ..height = '${chartHeight}px'
      ..paddingTop = '${padding}px'
      ..paddingBottom = '${padding}px';

    timelineController.onFrameAdded.listen((TimelineFrame frame) {
      final CoreElement frameUI = FrameBar(this, frame);
      if (element.children.isEmpty) {
        add(frameUI);
      } else {
        if (element.children.length >= maxFrames) {
          element.children.removeLast();
        }
        element.children.insert(0, frameUI.element);
      }
    });
  }

  static const int chartHeight = 200;
  static const int maxFrames = 120;
  static const padding = 5;

  FrameBar selectedFrame;

  final StreamController<TimelineFrame> _selectedFrameController =
      StreamController<TimelineFrame>.broadcast();

  Stream<TimelineFrame> get onSelectedFrame => _selectedFrameController.stream;

  void setSelected(FrameBar frameUI) {
    if (selectedFrame == frameUI) {
      return;
    }

    if (selectedFrame != frameUI) {
      selectedFrame?.setSelected(false);
      selectedFrame = frameUI;
      selectedFrame?.setSelected(true);

      _selectedFrameController.add(selectedFrame?.frame);
    }
  }
}

class FrameBar extends CoreElement {
  FrameBar(this.framesBarChart, this.frame)
      : super('div', classes: 'timeline-frame') {
    layoutVertical();

    _initialize();

    click(() {
      framesBarChart.setSelected(this);
    });
  }

  // Chart height minus padding on top and bottom.
  static const maxBarHeight =
      FramesBarChart.chartHeight - (FramesBarChart.padding * 2);

  // Let a 16ms frame take up 1/3 of the [TimelineFramesUI] height, so we should
  // be able to fit 48ms (3x16) in [chartHeight] pixels.
  static const double pxPerMs = maxBarHeight / 48;

  final FramesBarChart framesBarChart;
  final TimelineFrame frame;
  CoreElement _cpuBar;
  CoreElement _gpuBar;

  void _initialize() {
    final cpuBarHeight = math.min(maxBarHeight, frame.cpuDurationMs * pxPerMs);

    // If we are going to run out of room to display the frame bar, trim the gpu
    // portion.
    final gpuBarHeight =
        math.min(maxBarHeight - cpuBarHeight, frame.gpuDurationMs * pxPerMs);

    final cpuTooltip = frame.isCpuSlow
        ? _slowFrameWarning('CPU', msAsText(frame.cpuDurationMs))
        : 'CPU: ${msAsText(frame.cpuDurationMs)}';
    final gpuTooltip = frame.isGpuSlow
        ? _slowFrameWarning('GPU', msAsText(frame.gpuDurationMs))
        : 'GPU: ${msAsText(frame.gpuDurationMs)}';

    _cpuBar = div(c: 'bar bottom');
    _cpuBar.element.title = cpuTooltip;
    _cpuBar.element.style
      ..height = '${cpuBarHeight}px'
      ..backgroundColor = colorToCss(_getCpuBarColor());

    _gpuBar = div(c: 'bar top');
    _gpuBar.element.title = gpuTooltip;
    _gpuBar.element.style
      ..height = '${gpuBarHeight}px'
      ..backgroundColor = colorToCss(_getGpuBarColor());

    element.style.height = '${cpuBarHeight + gpuBarHeight}px';

    add(_gpuBar);
    add(_cpuBar);
  }

  Color _getCpuBarColor() {
    return frame.isCpuSlow ? slowFrameColor : mainCpuColor;
  }

  Color _getGpuBarColor() {
    return frame.isGpuSlow ? slowFrameColor : mainGpuColor;
  }

  String _slowFrameWarning(String type, String duration) {
    return 'The $type portion of this frame took $duration to render. This is '
        'longer than 8 ms, which can cause frame rate to drop below 60 FPS.';
  }

  void setSelected(bool selected) {
    toggleClass('selected', selected);
    _cpuBar.element.style.backgroundColor = selected
        ? colorToCss(selectedColor)
        : colorToCss(_getCpuBarColor());
    _gpuBar.element.style.backgroundColor = selected
        ? colorToCss(selectedColor)
        : colorToCss(_getGpuBarColor());
  }
}
