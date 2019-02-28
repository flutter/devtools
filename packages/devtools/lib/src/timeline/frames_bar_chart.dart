// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../ui/elements.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/plotly.dart';
import 'frames_bar_plotly.dart';
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
      ..paddingTop = '${topPadding}px';

    timelineController.onFrameAdded.listen((TimelineFrame frame) {
      if (frameUIgraph == null) {
        frameUIgraph = PlotlyDivGraph(this, frame, false); // Process chunks
        add(frameUIgraph);
      }

      frameUIgraph.process(timelineController, frame);
    });
  }

  static const int chartHeight = 160;
  static const int maxFrames = 500;
  static const topPadding = 2;

  TimelineFrame selectedFrame;
  PlotlyDivGraph frameUIgraph;

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
  PlotlyDivGraph(this.framesBarChart, this.frame, [bool datum = true])
      : _processDatum = datum,
        super('div') {
    element.id = frameGraph;
    element.style
      ..height = '100%'
      ..width = '100%';
  }

  static const String frameGraph = 'graph_frame_timeline';

  bool _processDatum;
  Timer timer;
  final FramesBarChart framesBarChart;
  final TimelineFrame frame;
  final Map<int, TimelineFrame> _frames = {};

  List<int> dataIndexes = [];
  List<num> cpuDurations = [];
  List<num> gpuDurations = [];

  FramesBarPlotly plotlyChart;

  // X coordinate 0 for real data (xCoordNotUsed is reserved for each trace
  // since first bar color isn't shown when x coord is xCoordNotUsed.
  int _frameIndex = FramesBarPlotly.xCoordFirst;
  int _lastPlottedFrameIndex = -1;
  bool _createdPlot = false;

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

  Selection currentSelection = null;

  void _plotlyClick(DataEvent data) {
    final int xPosition = data.points[0].x;

    List<SelectTrace> newSelection = [];

    for (Point pt in data.points) {
      // Don't allow selecting an already selected bar.
      if (pt.curveNumber != FramesBarPlotly.gpuSelectTraceIndex &&
          pt.curveNumber != FramesBarPlotly.cpuSelectTraceIndex) {
        newSelection
            .add(SelectTrace(pt.curveNumber, pt.pointNumber, pt.x, pt.y));
      }
    }

    // Create selection once.
    currentSelection ??= Selection(frameGraph, element);

    // If this bar isn't currently selected then select the bar clicked.
    if (newSelection.length == 2 &&
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

    // Hovering over a selected bar?
    bool selectionTrace = false;

    for (Point pt in data.points) {
      final int ptNumber = pt.pointNumber;
      final int x = pt.data.x[ptNumber];
      // Only display the hover if its not the first data point for each trace
      // (curveNumber). Works around first bar in a trace color not rendered.
      if (x != FramesBarPlotly.xCoordNotUsed) {
        selectionTrace |=
            (pt.curveNumber == FramesBarPlotly.gpuSelectTraceIndex) ||
                (pt.curveNumber == FramesBarPlotly.cpuSelectTraceIndex);
        hoverDisplay.add(
            HoverFX(curveNumber: pt.curveNumber, pointNumber: pt.pointNumber));
      }
    }

    if (selectionTrace) {
      // Hide the hover of the gpu good/jank & cpu good/jank trace of the
      // selected bar.
      for (var fx in hoverDisplay) {
        final int traceIndex = fx.curveNumber;
        if (traceIndex == FramesBarPlotly.gpuGoodTraceIndex ||
            traceIndex == FramesBarPlotly.gpuJankTraceIndex ||
            traceIndex == FramesBarPlotly.cpuGoodTraceIndex ||
            traceIndex == FramesBarPlotly.cpuJankTraceIndex) {
          hoverDisplay.remove(fx);
        }
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

  void process(
      TimelineController timelineController, TimelineFrame frame) async {
    if (!_createdPlot) {
      plotlyChart = new FramesBarPlotly(frameGraph);
      plotlyChart.plotFPS();

      _createdPlot = true;

      // Hookup events in the plotly chart.
      plotlyChart.chartClick(frameGraph, _plotlyClick);
      plotlyChart.chartHover(frameGraph, _plotlyHover);
      plotlyChart.chartLegendClick(frameGraph, _plotlyLegendClick);

      if (!_processDatum) {
        // Only update data 6 times a second.
        // TODO(jacobr): only run the timer when there is actual work to do.
        timer = Timer.periodic(const Duration(milliseconds: 166), (Timer t) {
          // Skip if there is no new data.
          if (_lastPlottedFrameIndex == _frameIndex) return;
          _lastPlottedFrameIndex = _frameIndex;
          plotData(timelineController);
        });
      }
    }

    if (_processDatum) {
      // TODO(terry): Either making this faster or remove and use chunking.
      plotlyChart.plotFPSDatum(_frameIndex, frame.cpuDurationMs,
          frame.gpuDurationMs, timelineController.paused);
    } else {
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
}
