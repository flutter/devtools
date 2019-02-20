// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../ui/elements.dart';
import '../ui/plotly.dart';
import 'frames_bar_plotly.dart';
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

  int _frameIndex = 0;
  int _lastPlottedFrameIndex = 0;
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

  void _plotlyClick(DataEvent data) {
    final int xPosition = data.points[0].x;
    if (_frames.containsKey(xPosition)) {
      final TimelineFrame timelineFrame = _frames[xPosition];
      framesBarChart.setSelected(timelineFrame);
    }
  }

  void process(
      TimelineController timelineController, TimelineFrame frame) async {
    if (!_createdPlot) {
      plotlyChart = new FramesBarPlotly(frameGraph);
      plotlyChart.plotFPS();

      _createdPlot = true;

      // Hookup clicks in the plotly chart.
      plotlyChart.chartClick(frameGraph, _plotlyClick);

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
        print('WARNING: Ignored onFrameAdded - bad data');
      }
    }
  }
}
