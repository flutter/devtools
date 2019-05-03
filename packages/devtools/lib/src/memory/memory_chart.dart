// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import '../timeline/frames_bar_chart.dart';
import '../ui/elements.dart';
import 'memory_controller.dart';
import 'memory_plotly.dart';
import 'memory_protocol.dart';

class MemoryChart extends CoreElement {
  MemoryChart(this._memoryController)
      : super('div', classes: 'section section-border') {
    layoutVertical();

    element.id = _memoryGraph;
    element.style
      ..boxSizing = 'content-box' // border-box causes right/left border cut.
      ..height = '${FramesBarChart.chartHeight}px'
      ..width = '100%';

    _memoryController.onMemory.listen((MemoryTracker memoryTracker) {
      if (_memoryController.memoryTracker.hasConnection) {
        updateChart(memoryTracker);
      }
    });
  }

  static const String _memoryGraph = 'memory_timeline';

  // Height of chart when event timeline is visible.
  final int _memoryGraphEventTimelineHeight = 230;

  final MemoryController _memoryController;

  bool _chartCreated = false;
  MemoryPlotly _plotlyChart;

  int lastGcTimestamp = 0;

  void updateChart(MemoryTracker data) {
    if (!_chartCreated) {
      _plotlyChart = MemoryPlotly(_memoryGraph, this)..plotMemory();
      _chartCreated = true;
    }

    for (HeapSample newSample in data.samples) {
      if (newSample.isGC) {
        num gcValue;
        num gcTimeStamp;

        gcTimeStamp = newSample.timestamp;
        // TODO(terry): Sometimes 2 GCs events arrive within 500 ms only record
        // TODO:        one to reducing chatter in the chart.  Filed issue:
        // TODO:        https://github.com/dart-lang/sdk/issues/36167
        if (gcTimeStamp - lastGcTimestamp > 500) {
          gcValue = newSample.capacity;
          _plotlyChart.plotMarkersDataList([gcTimeStamp], [gcValue]);
        }
        lastGcTimestamp = gcTimeStamp;
      }

      _plotlyChart.plotMemoryDataList(
        [newSample.timestamp],
        [newSample.rss],
        [newSample.capacity],
        [newSample.used],
        [newSample.external],
      );
    }
    data.samples.clear();
  }

  void pause() {
    _plotlyChart.liveUpdate = false;
  }

  void resume() {
    _plotlyChart.liveUpdate = true;
  }

  void plotSnapshot() {
    if (element.style.height != '${_memoryGraphEventTimelineHeight}px') {
      element.style..height = '${_memoryGraphEventTimelineHeight}px';
      element.dispatchEvent(new Event('resize'));
    }
    _plotlyChart.plotSnapshot();
  }

  void plotReset() {
    if (element.style.height != '${_memoryGraphEventTimelineHeight}px') {
      element.style..height = '${_memoryGraphEventTimelineHeight}px';
      element.dispatchEvent(new Event('resize'));
    }
    _plotlyChart.plotReset();
  }
}
