// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:plotly_js/plotly.dart' hide Title, RangeSlider;

import '../config_specific/logger.dart';
import '../framework/html_framework.dart';
import '../ui/analytics.dart' as ga;
import '../ui/html_elements.dart';
import 'frames_bar_plotly.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

class FramesBarChart extends CoreElement with HtmlSetStateMixin {
  FramesBarChart(this.timelineController)
      : super('div', classes: 'timeline-frames section section-border') {
    // No frame around component, so data spikes can appear to go through the
    // roof (highest horizontal line is 100 ms).
    layoutHorizontal();
    element.style
      ..alignItems = 'flex-end'
      ..height = '${chartHeight}px'
      ..width = '100%'
      ..paddingTop = '${topPadding}px';

    frameUIgraph = PlotlyDivGraph(this, timelineController);
    add(frameUIgraph);

    // Make sure DIV exist.
    setState(() {
      if (!_createdPlot) {
        createFirstPlot();
      }
    });

    timelineController.frameBasedTimeline.frameAddedNotifier.addListener(() {
      frameUIgraph.processNextFrame();
    });
  }

  Future<void> createFirstPlot() async {
    frameUIgraph.createPlot(frameUIgraph.element,
        await timelineController.frameBasedTimeline.displayRefreshRate);
    _createdPlot = true;
  }

  static const int chartHeight = 140;
  static const int maxFrames = 500;
  static const topPadding = 2;

  final TimelineController timelineController;

  PlotlyDivGraph frameUIgraph;

  bool _createdPlot = false;
}

class PlotlyDivGraph extends CoreElement {
  PlotlyDivGraph(this.framesBarChart, this.timelineController) : super('div') {
    element.id = frameGraph;
    element.style
      ..height = '100%'
      ..width = '100%';
  }

  static const String frameGraph = 'graph_frame_timeline';

  final FramesBarChart framesBarChart;

  final TimelineController timelineController;

  final Map<int, TimelineFrame> _frames = {};

  List<int> dataIndexes = [];
  List<num> uiDurations = [];
  List<num> gpuDurations = [];

  FramesBarPlotly plotlyChart;

  // X coordinate 0 for real data (xCoordNotUsed is reserved for each trace
  // since first bar color isn't shown when x coord is xCoordNotUsed.
  int _frameIndex = FramesBarPlotly.xCoordFirst;
  int _lastPlottedFrameIndex = -1;

  /// These lists are batch updated to the plotly chart to reduce chart lag
  /// relative to updating every frame.
  void plotData() {
    final int dataLength = dataIndexes.length;
    if (dataLength > 0) {
      plotlyChart.plotFPSDataList(
        dataIndexes,
        uiDurations,
        gpuDurations,
        timelineController.frameBasedTimeline.pausedNotifier.value,
      );

      dataIndexes.removeRange(0, dataLength);
      uiDurations.removeRange(0, dataLength);
      gpuDurations.removeRange(0, dataLength);
    }
  }

  Selection currentSelection;

  void _plotlyClick(DataEvent data) {
    final num xPosition = data.points[0].x;

    final List<SelectTrace> newSelection = [];

    for (Point pt in data.points) {
      if (pt.curveNumber != FramesBarPlotly.gpuSelectTraceIndex &&
          pt.curveNumber != FramesBarPlotly.uiSelectTraceIndex) {
        newSelection.add(SelectTrace(
          pt.curveNumber,
          pt.pointNumber,
          pt.x,
          pt.y,
        ));
      }
    }

    // Create selection once.
    currentSelection ??= Selection(frameGraph, element);

    // Don't allow selecting an already selected bar.  If this bar isn't
    // currently selected then select the bar clicked.  Also, newSelection
    // should always have 2 entries a point in the frames bar chart always
    // exist in 2 traces a gpu duration is either in the good/junk trace and the
    // same is true for UI too.
    if (newSelection.length == FramesBarPlotly.activeTracesPerX &&
        !currentSelection.isSelected(newSelection)) {
      currentSelection.select(newSelection);

      if (_frames.containsKey(xPosition)) {
        final TimelineFrame timelineFrame = _frames[xPosition];
        timelineController.frameBasedTimeline.selectFrame(timelineFrame);
        ga.selectFrame(
          ga.timeline,
          ga.timelineFrame,
          timelineFrame.gpuDuration,
          timelineFrame.uiDuration,
        );
      }
    }
  }

  void _plotlyHover(DataEvent data) {
    final List<HoverFX> hoverDisplay = [];

    for (Point pt in data.points) {
      final int ptNumber = pt.pointNumber;
      final int x = pt.data.x[ptNumber];
      // Only display the hover if its not the first data point for each trace
      // (curveNumber). Works around first bar in a trace color not rendered.
      if (x != FramesBarPlotly.xCoordNotUsed) {
        hoverDisplay.add(
            HoverFX(curveNumber: pt.curveNumber, pointNumber: pt.pointNumber));
      }
    }

    plotFXHover(frameGraph, hoverDisplay);
  }

  void createPlot(dynamic element, double displayRefreshRate) {
    plotlyChart = FramesBarPlotly(
      frameGraph,
      element,
      useLogScale: false,
      showRangeSlider: false,
      displayRefreshRate: displayRefreshRate,
    );
    plotlyChart.plotFPS();

    // Hookup events in the plotly chart.
    plotlyChart.chartClick(frameGraph, _plotlyClick);
    plotlyChart.chartHover(frameGraph, _plotlyHover);

    // Only update data 6 times a second.
    // TODO(jacobr): only run the timer when there is actual work to do.
    Timer.periodic(const Duration(milliseconds: 166), (Timer t) {
      // Skip if there is no new data.
      if (_lastPlottedFrameIndex == _frameIndex) return;
      _lastPlottedFrameIndex = _frameIndex;
      plotData(); // Plot the chunks of data collected.
    });
  }

  // Add current frame data to chunks of data for later plotting.
  void processNextFrame() async {
    final frame =
        timelineController.frameBasedTimeline.frameAddedNotifier.value;
    if (frame == null) return;

    if (frame.uiDurationMs > 0 && frame.gpuDurationMs > 0) {
      dataIndexes.add(_frameIndex);
      uiDurations.add(frame.uiDurationMs);
      gpuDurations.add(frame.gpuDurationMs);

      _frames.addAll({_frameIndex: frame});

      _frameIndex++;
    } else {
      // TODO(terry): HACK - Ignore the event.
      log(
        'Ignored onFrameAdded - bad data.\n [uiDuration: '
        '${frame.uiDuration}, gpuDuration: ${frame.gpuDuration}',
        LogLevel.warning,
      );
    }
  }

  void reset({@required double displayRefreshRate}) {
    dataIndexes.clear();
    uiDurations.clear();
    gpuDurations.clear();
    _frames.clear();
    _frameIndex = FramesBarPlotly.xCoordFirst;
    _lastPlottedFrameIndex = -1;
    currentSelection = null;
    createPlot(element, displayRefreshRate);
  }
}
