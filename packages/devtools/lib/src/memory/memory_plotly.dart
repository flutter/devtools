// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/memory/memory.dart';
import '../ui/plotly.dart';

class MemoryPlotly {
  MemoryPlotly(this._domName, this._memoryChart);

  final String _domName;
  final MemoryChart _memoryChart;

  Layout getMemoryLayout(chartTitle) {
    return Layout(
        title: chartTitle,
        xaxis: AxisLayout(
          type: 'date',
          tickformat: '%-I:%M:%S %p',
          hoverformat: '%M:%S.%L %p',
          range: [],
          rangeslider: RangeSlider(),
        ),
        yaxis: AxisLayout(
          title: 'Heap',
          fixedrange: true,
        ),
        margin: Margin(l: 80, r: 0, b: 5, t: 5, pad: 5));
  }

//  static const int MEMORY_GC_TRACE = 0;   // TODO(terry):
  static const int MEMORY_EXTERNAL_TRACE = 0;
  static const int MEMORY_USED_TRACE = 1;
  static const int MEMORY_CAPACITY_TRACE = 2;
  static const int MEMORY_RSS_TRACE = 3;

  // TODO(terry): expose as CSSColor and Themed.
  static const String RSS_COLOR = '#F1B876';
  static const String CAPACITY_COLOR = '#C0C0C0';
  static const String EXTERNAL_COLOR = '#4794C0';
  static const String USED_COLOR = '#48B2E7';

  List<Data> createMemoryTraces() {
    /* TODO(terry): Enable gc markers.
    final Data normalized_trace = Data(
      y: [],
      x: [],
      type: 'scatter',
      mode: 'markers',
      marker: Marker(
        symbol: 'circle',
        size: 10,
      ),
      name: 'GC',
      text: [],
      hoverinfo: 'y+name',
    );
    */

    final Data externalTrace = Data(
      x: [],
      y: [],
      text: [],
      line: Line(
        color: EXTERNAL_COLOR,
      ),
      type: 'scatter',
      stackgroup: 'one',
      name: 'External',
    );

    final Data usedTrace = Data(
      x: [],
      y: [],
      text: [],
      line: Line(
        color: USED_COLOR,
      ),
      type: 'scatter',
      stackgroup: 'one',
      name: 'Used',
    );

    final Data capacityTrace = Data(
      x: [],
      y: [],
      text: [],
      line: Line(
        color: CAPACITY_COLOR,
        dash: 'dot',
        width: 2,
      ),
      type: 'scatter',
      mode: 'lines',
      name: 'Capacity',
    );

    final Data rssTrace = Data(
      x: [],
      y: [],
      text: [],
      line: Line(
        color: RSS_COLOR,
        dash: 'dash',
        width: 2,
      ),
      type: 'scatter',
      visible: 'legendonly',
      mode: 'lines',
      name: 'RSS',
    );

    return [externalTrace, usedTrace, capacityTrace, rssTrace];
  }

  // Resetting to live view, it's an autoscale back to full view.
  void _doubleClick(DataEvent data) => _memoryChart.resume();

  void plotMemory() {
    Plotly.newPlot(
      _domName,
      createMemoryTraces(),
      getMemoryLayout(''),
      Configuration(
        responsive: true,
        displaylogo: false,
        displayModeBar: false,
      ),
    );

    doubleClick(_domName, _doubleClick);
  }

  void plotMemoryDataList(
    List<int> timestamps,
    List<num> rsses,
    List<num> capacities,
    List<num> uses,
    List<num> externals,
  ) {
    // TODO(terry): Eliminate this JS call (result of reified List?).
    myExtendTraces(
      _domName,
      timestamps,
      timestamps,
      timestamps,
      timestamps,
      rsses,
      capacities,
      externals,
      uses,
      [
        MEMORY_RSS_TRACE,
        MEMORY_CAPACITY_TRACE,
        MEMORY_EXTERNAL_TRACE,
        MEMORY_USED_TRACE,
      ],
    );

    if (liveUpdate) {
      // Display 2 minutes of collected data in the chart, all data is accessible.
      final int startTime = DateTime.fromMillisecondsSinceEpoch(timestamps[0])
          .subtract(const Duration(minutes: 2))
          .millisecondsSinceEpoch;
      rangeSliderToLast(startTime, timestamps[0]);
    }
  }

  void rangeSliderToLast(int startTime, int endTime) {
    Plotly.update(
      _domName,
      [Data()],
      Layout(
        xaxis: AxisLayout(
          range: [startTime, endTime],
          rangeslider: RangeSlider(
            autorange: true,
          ),
          type: 'date',
          tickformat: '%-I:%M:%S %p',
          hoverformat: '%-I:%M:%S.%L %p',
        ),
      ),
    );
  }

  bool liveUpdate = true;

  void setLiveUpdate({bool live}) {
    liveUpdate = live;
  }
}
