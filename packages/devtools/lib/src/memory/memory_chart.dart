// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../timeline/frames_bar_chart.dart';
import '../ui/elements.dart';

import 'memory.dart';
import 'memory_controller.dart';
import 'memory_plotly.dart';
import 'memory_protocol.dart';

class MemoryChart extends CoreElement {
  MemoryChart(this._memoryScreen, this._memoryController)
      : super('div', classes: 'section section-border') {
    layoutVertical();

    element.id = _memoryGraph;
    element.style
      ..boxSizing = 'content-box' // border-box causes right/left border cut.
      ..height = '${FramesBarChart.chartHeight}px';

    _memoryController.onMemory.listen((MemoryTracker memoryTracker) {
      if (!_memoryController.memoryTracker.hasConnection) {
        // VM Service connection has stopped.
        _memoryScreen.serviceDisconnet();
      } else {
        updateChart(memoryTracker);
      }
    });
  }

  static const String _memoryGraph = 'memory_timeline';

  final MemoryScreen _memoryScreen;
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

        print('GC occurred $gcTimeStamp');

        gcTimeStamp = newSample.timestamp;
        // TODO(terry): Check with VM on this strange occurance.
        // Sometimes two GCs come in within 500 ms only record one.
        if (gcTimeStamp - lastGcTimestamp > 500) {
          print('GC plotting $gcTimeStamp');
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
    _memoryScreen.updatePauseButton(disabled: true);
    _memoryScreen.updateResumeButton(disabled: false);

    _plotlyChart.liveUpdate = false;
  }

  void resume() {
    _memoryScreen.updateResumeButton(disabled: true);
    _memoryScreen.updatePauseButton(disabled: false);

    _plotlyChart.liveUpdate = true;
  }
}
