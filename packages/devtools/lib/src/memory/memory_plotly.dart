// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/plotly.dart';

import 'memory.dart';

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
        margin: Margin(l: 80, r: 5, b: 5, t: 5, pad: 5));
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

  Data _createTrace(String name, String color, {String group, String dash}) {
    String dashName = '';
    int widthValue = 0;
    String modeName = '';

    if (dash != null) {
      dashName = dash;
      widthValue = 2;
      modeName = 'lines';
    }
    return Data(
      x: [],
      y: [],
      text: [],
      line: Line(
        color: color,
        dash: dashName,
        width: widthValue,
      ),
      type: 'scatter',
      mode: modeName,
      stackgroup: group != null ? 'one' : '',
      name: name,
    );
  }

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

    final Data externalTrace = _createTrace(
      'External',
      EXTERNAL_COLOR,
      group: 'one',
    );
    final Data usedTrace = _createTrace(
      'Used',
      USED_COLOR,
      group: 'one',
    );
    final Data capacityTrace = _createTrace(
      'Capacity',
      CAPACITY_COLOR,
      dash: 'dot',
    );
    final Data rssTrace = _createTrace(
      'RSS',
      RSS_COLOR,
      dash: 'dash',
    );
    rssTrace.visible = 'legendonly';

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
      timestamps, // x coordinates for RSS trace.
      timestamps, // x coordinates for capacity trace.
      timestamps, // x coordinates for external trace.
      timestamps, // x coordinates for used trace.
      rsses, // y coordinates for RSS trace.
      capacities, // y coordinates for capacity trace.
      externals, // y coordinates for external trace.
      uses, // y coordinates for used trace.
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
