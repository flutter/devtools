// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

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
    layoutVertical();

    element.style.height = '${chartHeight}px';

    final CoreElement frames = div(c: 'frames-container')
      ..layoutHorizontal()
      ..flex()
      ..element.style.alignItems = 'flex-end'
      ..height = '${chartHeight}px';
    add(frames);

    timelineController.onFrameAdded.listen((TimelineFrame frame) {
      final CoreElement frameUI = FrameBar(this, frame);
      if (frames.element.children.isEmpty) {
        frames.add(frameUI);
      } else {
        if (frames.element.children.length >= maxFrames) {
          frames.element.children.removeLast();
        }
        frames.element.children.insert(0, frameUI.element);
      }
    });

    // Add horizontal lines for frame MS targets.
    for (int i = 1; i <= 5; i++) {
      final num y = (TimelineFrame.targetMaxDuration / 2.0) * i * pxPerMs;
      final CoreElement divider = div(c: 'divider-line');
      divider.element.style.bottom = '${y}px';
      if (i % 2 == 1) {
        divider.toggleClass('subtle');
      }
      add(divider);
    }
  }

  static const int chartHeight = 100;
  static const int maxFrames = 120;

  // Let a 16ms frame take up 1/3 of the [TimelineFramesUI] height, so we should
  // be able to fit 48ms (3x16) in [chartHeight] pixels.
  static const double pxPerMs =
      chartHeight / (TimelineFrame.targetMaxDuration * 3);

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

  // Chart height minus top padding.
  static const maxBarHeight = FramesBarChart.chartHeight;

  final FramesBarChart framesBarChart;
  final TimelineFrame frame;
  CoreElement _cpuBar;
  CoreElement _gpuBar;

  void _initialize() {
    final cpuBarHeight = frame.cpuDurationMs * FramesBarChart.pxPerMs;
    final gpuBarHeight = frame.gpuDurationMs * FramesBarChart.pxPerMs;

    final cpuTooltip = frame.isCpuSlow
        ? _slowFrameWarning('CPU', msAsText(frame.cpuDurationMs))
        : 'CPU: ${msAsText(frame.cpuDurationMs)}';
    final gpuTooltip = frame.isGpuSlow
        ? _slowFrameWarning('GPU', msAsText(frame.gpuDurationMs))
        : 'GPU: ${msAsText(frame.gpuDurationMs)}';

    _cpuBar = div(c: 'bar top');
    _cpuBar.element.title = cpuTooltip;
    _cpuBar.element.style
      ..height = '${cpuBarHeight}px'
      ..backgroundColor = colorToCss(_getCpuBarColor());

    _gpuBar = div(c: 'bar bottom');
    _gpuBar.element.title = gpuTooltip;
    _gpuBar.element.style
      ..height = '${gpuBarHeight}px'
      ..backgroundColor = colorToCss(_getGpuBarColor());

    element.style.height = '${cpuBarHeight + gpuBarHeight}px';

    add(_cpuBar);
    add(_gpuBar);
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
    _cpuBar.element.style.backgroundColor =
        selected ? colorToCss(selectedColor) : colorToCss(_getCpuBarColor());
    _gpuBar.element.style.backgroundColor =
        selected ? colorToCss(selectedColor) : colorToCss(_getGpuBarColor());
  }
}
