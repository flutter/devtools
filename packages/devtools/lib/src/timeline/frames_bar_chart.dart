// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../framework/framework.dart';
import '../ui/elements.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/plotly.dart';
import 'frames_bar_plotly.dart';
import 'timeline.dart';
import 'timeline_controller.dart';
import 'timeline_protocol.dart';

class FramesBarChart extends CoreElement with SetStateMixin {
  FramesBarChart(TimelineController timelineController)
      : super('div', classes: 'timeline-frames') {
    // No frame around component, so data spikes can appear to go through the
    // roof (highest horizontal line is 100 ms).
    layoutHorizontal();
    element.style
      ..alignItems = 'flex-end'
      ..height = '${chartHeight}px'
      ..paddingTop = '${topPadding}px';

    frameUIgraph = PlotlyDivGraph(this, timelineController);
    add(frameUIgraph);

    // Make sure DIV exist.
    setState(() {
      if (!_createdPlot) {
        frameUIgraph.createPlot(timelineController);
        _createdPlot = true;
      }
    });

    timelineController.onFrameAdded.listen((TimelineFrame frame) {
      frameUIgraph.process(timelineController, frame);
    });
  }

  static const int chartHeight = 160;
  static const int maxFrames = 500;
  static const topPadding = 2;

  TimelineFrame selectedFrame;
  PlotlyDivGraph frameUIgraph;
  bool _createdPlot = false;

  final StreamController<TimelineFrame> _selectedFrameController =
      StreamController<TimelineFrame>.broadcast();

  Stream<TimelineFrame> get onSelectedFrame => _selectedFrameController.stream;

  void setSelected(TimelineFrame frame) {
    if (selectedFrame == frame) {
      return;
    }

    selectedFrame = frame;
    _selectedFrameController.add(frame);
  }
}

class PlotlyDivGraph extends CoreElement {
  PlotlyDivGraph(this.framesBarChart, TimelineController timelineController)
      : super('div') {
    element.id = frameGraph;
    element.style
      ..height = '100%'
      ..width = '100%';
  }

  static const String frameGraph = 'graph_frame_timeline';

  Timer timer;
  final FramesBarChart framesBarChart;
  TimelineFrame frame;
  final Map<int, TimelineFrame> _frames = {};

  List<int> dataIndexes = [];
  List<num> cpuDurations = [];
  List<num> gpuDurations = [];

  FramesBarPlotly plotlyChart;

  // X coordinate 0 for real data (xCoordNotUsed is reserved for each trace
  // since first bar color isn't shown when x coord is xCoordNotUsed.
  int _frameIndex = FramesBarPlotly.xCoordFirst;
  int _lastPlottedFrameIndex = -1;

  /// These lists are batch updated to the plotly chart to reduce chart lag
  /// relative to updating every frame.
  void plotData(TimelineController timelineController) {
    final int dataLength = dataIndexes.length;
    if (dataLength > 0) {
      plotlyChart.plotFPSDataList(
          dataIndexes, cpuDurations, gpuDurations, timelineController.paused);

      dataIndexes.removeRange(0, dataLength);
      cpuDurations.removeRange(0, dataLength);
      gpuDurations.removeRange(0, dataLength);
    }
  }

  Selection currentSelection;

  void _plotlyClick(DataEvent data) {
    final num xPosition = data.points[0].x;

    final List<SelectTrace> newSelection = [];

    for (Point pt in data.points) {
      if (pt.curveNumber != FramesBarPlotly.gpuSelectTraceIndex &&
          pt.curveNumber != FramesBarPlotly.cpuSelectTraceIndex) {
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
    // same is true for cpu too.
    if (newSelection.length == FramesBarPlotly.activeTracesPerX &&
        !currentSelection.isSelected(newSelection)) {
      currentSelection.select(newSelection);

      if (_frames.containsKey(xPosition)) {
        final TimelineFrame timelineFrame = _frames[xPosition];
        framesBarChart.setSelected(timelineFrame);
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

  bool _plotlyLegendClick(LegendDataEvent data) {
    final int traceIndex = data.curveNumber;

    if (traceIndex == FramesBarPlotly.cpuJankTraceIndex ||
        traceIndex == FramesBarPlotly.gpuJankTraceIndex) {
      final List<int> traces = [
        FramesBarPlotly.cpuJankTraceIndex,
        FramesBarPlotly.gpuJankTraceIndex
      ];

      final String color = data.data[traceIndex].marker.color;

      String newCpuColor;
      String newGpuColor;

      if (color == colorToCss(cpuJankColor) ||
          color == colorToCss(gpuJankColor)) {
        // Flip to cpuGoodColor/gpuGoodColor
        newCpuColor = colorToCss(mainCpuColor);
        newGpuColor = colorToCss(mainGpuColor);
      } else {
        // Flip back to cpuJankColor/gpuJankColor
        newCpuColor = colorToCss(cpuJankColor);
        newGpuColor = colorToCss(gpuJankColor);
      }

      Plotly.restyle(
        frameGraph,
        'marker.color',
        [newCpuColor, newGpuColor],
        traces,
      );

      return false;
    }

    return true;
  }

  void createPlot(TimelineController timelineController) {
    plotlyChart = new FramesBarPlotly(frameGraph);
    plotlyChart.plotFPS();

    // Hookup events in the plotly chart.
    plotlyChart.chartClick(frameGraph, _plotlyClick);
    plotlyChart.chartHover(frameGraph, _plotlyHover);
    plotlyChart.chartLegendClick(frameGraph, _plotlyLegendClick);

    // Only update data 6 times a second.
    // TODO(jacobr): only run the timer when there is actual work to do.
    timer = Timer.periodic(const Duration(milliseconds: 166), (Timer t) {
      // Skip if there is no new data.
      if (_lastPlottedFrameIndex == _frameIndex) return;
      _lastPlottedFrameIndex = _frameIndex;
      plotData(timelineController); // Plot the chunks of data collected.
    });
  }

  // Add current frame data to chunks of data for later plotting.
  void process(
      TimelineController timelineController, TimelineFrame frame) async {
    // TODO(terry): Eventually, below failure can happen, then onFrameAdded
    //              events may not be received or the data can go negative
    //              add sentry to detect bad values.
    //
    //    Error - already set endTime ### for frame 1650.
    //    TraceEvent - {name: PipelineItem, cat: Embedder, tid: ###, pid: ###, ts: ###, ph: f, bp: e, id: ##, args: {}}
    if (frame.cpuDurationMs > 0 && frame.gpuDurationMs > 0) {
      dataIndexes.add(_frameIndex);
      cpuDurations.add(frame.cpuDurationMs);
      gpuDurations.add(frame.gpuDurationMs);

      _frames.addAll({_frameIndex: frame});

      _frameIndex++;
    } else {
      // TODO(terry): HACK - Ignore the event.
      print('WARNING: Ignored onFrameAdded - bad data.\n [cpuDuration: '
          '${frame.cpuDuration}, gpuDuration: ${frame.gpuDuration}');
    }
  }
}
