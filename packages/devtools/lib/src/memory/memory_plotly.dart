// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/plotly.dart';

import 'memory_chart.dart';

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

  static const int MEMORY_GC_TRACE = 0;
  static const int MEMORY_EXTERNAL_TRACE = 1;
  static const int MEMORY_USED_TRACE = 2;
  static const int MEMORY_CAPACITY_TRACE = 3;
  static const int MEMORY_RSS_TRACE = 4;

  // TODO(terry): expose as CSSColor and Themed.
  static const String RSS_COLOR = '#F1B876';
  static const String CAPACITY_COLOR = '#C0C0C0';
  static const String EXTERNAL_COLOR = '#4794C0';
  static const String USED_COLOR = '#48B2E7';

  Data _createTrace(
    String name, {
    String color,
    String group,
    String dash,
    String symbol,
    int size,
  }) {
    int widthValue = 0;
    String modeName = '';

    Line line;
    if (color != null) {
      if (dash != null) {
        widthValue = 2;
        modeName = 'lines';
      }
      line = Line(color: color, dash: dash, width: widthValue);
    }

    Marker marker;
    if (symbol != null) {
      // Ignore color use symbol and size.
      marker = Marker(symbol: symbol, size: size);
      modeName = 'markers';
    }

    if (marker == null) {
      return Data(
        x: [],
        y: [],
        text: [],
        line: line,
        type: 'scatter',
        mode: modeName,
        stackgroup: group != null ? 'one' : '',
        name: name,
        hoverinfo: 'y+name',
      );
    } else {
      return Data(
        x: [],
        y: [],
        text: [],
        marker: marker,
        type: 'scatter',
        mode: modeName,
        stackgroup: group != null ? 'one' : '',
        name: name,
        hoverinfo: 'y+name',
      );
    }
  }

  List<Data> createMemoryTraces() {
    final Data gcTrace = _createTrace('GC', symbol: 'circle', size: 10);
    gcTrace.hoverinfo = 'x+name';

    final Data externalTrace = _createTrace(
      'External',
      color: EXTERNAL_COLOR,
      group: 'one',
    );
    final Data usedTrace = _createTrace(
      'Used',
      color: USED_COLOR,
      group: 'one',
    );
    final Data capacityTrace = _createTrace(
      'Capacity',
      color: CAPACITY_COLOR,
      dash: 'dot',
    );
    final Data rssTrace = _createTrace(
      'RSS',
      color: RSS_COLOR,
      dash: 'dash',
    );
    rssTrace.visible = 'legendonly';

    return [gcTrace, externalTrace, usedTrace, capacityTrace, rssTrace];
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

  void plotMarkersDataList(List<int> timestamps, List<num> gces) {
    extendTraces1(
      _domName,
      timestamps, // x coordinates for RSS trace.
      gces, // y coordinates for RSS trace.
      [
        MEMORY_GC_TRACE,
      ],
    );
  }

  void plotMemoryDataList(
    List<int> timestamps,
    List<num> rsses,
    List<num> capacities,
    List<num> uses,
    List<num> externals,
  ) {
    // TODO(terry): Eliminate this JS call (result of reified List?).
    extendTraces4(
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
