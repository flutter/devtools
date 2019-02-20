// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:mutex/mutex.dart';

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

  // Data is adding to a ploting graph every second or every 20 frames of data
  // collected.  Otherwise plotly will lag is displaying the data.
  static const int frameChunking = 20;

  bool _processDatum;
  Timer timer;
  final FramesBarChart framesBarChart;
  final TimelineFrame frame;
  final Map<int, TimelineFrame> _frames = {};

  ReadWriteMutex mutex = ReadWriteMutex();

  List<int> dataIndexes = [];
  List<num> cpuDurations = [];
  List<num> gpuDurations = [];

  FramesBarPlotly plotlyChart;

  int frameIndex = 0;
  bool _createdPlot = false;

  // This routine should only be called using a mutex.acquireWrite() as it's
  // destructive to our lists (collecting indexes, and durations) which are
  // stored on a FrameAdded event.  These lists are chunked to the plotly chart
  // to reduce chart lag. Chunking is defined as frameChunking frames received
  // or frames information received in a second (whichever comes first) are
  // plotted.
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
        // The once a second chunking (other chunking uses frameChunking).
        timer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
          // Get the lock.
          await mutex.acquireWrite();
          try {
            plotData(timelineController);
          } finally {
            // Release the lock.
            mutex.release();
          }
        });
      }
    }

    if (_processDatum) {
      // TODO(terry): Either making this faster or remove and use chunking.
      plotlyChart.plotFPSDatum(frameIndex, frame.cpuDurationMs,
          frame.gpuDurationMs, timelineController.paused);
    } else {
      // Get the lock.
      await mutex.acquireWrite();
      try {
        // TODO(terry): Eventually, below failure can happen, then onFrameAdded
        //              events may not be received or the data can go negative
        //              add sentry to detect bad values.
        //
        //    Error - already set endTime ### for frame 1650.
        //    TraceEvent - {name: PipelineItem, cat: Embedder, tid: ###, pid: ###, ts: ###, ph: f, bp: e, id: ##, args: {}}
        if (frame.cpuDurationMs > 0 && frame.gpuDurationMs > 0) {
          dataIndexes.add(frameIndex);
          cpuDurations.add(frame.cpuDurationMs);
          gpuDurations.add(frame.gpuDurationMs);

          _frames.addAll({frameIndex: frame});

          // Chunk the data every frameChunking frames otherwise Plotly lags.
          final int dataLength = dataIndexes.length;
          if (dataLength > frameChunking) {
            plotData(timelineController);
          }

          frameIndex++;
        } else {
          // TODO(terry): HACK - Ignore the event.
          print('WARNING: Ignored onFrameAdded - bad data');
        }
      } finally {
        // Release the lock.
        mutex.release();
      }
    }
  }
}
