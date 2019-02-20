// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../timeline/timeline.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/plotly.dart';

class FramesBarPlotly {
  FramesBarPlotly(this._domName);

  // Any duration of cpu/gpu greater than 8 ms is a jank.
  static const int jankMs = 8;

  static const int cpuGoodTraceIndex = 0;
  static const int cpuJankTraceIndex = 1;
  static const int gpuGoodTraceIndex = 2;
  static const int gpuJankTraceIndex = 3;
  static const int cpuHighWaterMarkTraceIndex = 4;
  static const int gpuHighWaterMarkTraceIndex = 5;

  static String cpuColor = colorToCss(mainCpuColor);
  static String gpuColor = colorToCss(mainGpuColor);

  static const String cpuJankColor = 'rgba(255, 0, 0, .8)'; // Border
  static const String gpuJankColor = 'rgba(255, 0, 0, .8)'; // Border

  // Default number of bars displayed in zoom (range slider).
  static const int ticksInRangeSlider = 70;

  final String _domName;

  Layout getFPSTimeseriesLayout(chartTitle) {
    return Layout(
      title: chartTitle,
      xaxis: AxisLayout(
        ticks: '',
        showgrid: false,
        showticklabels: false,
        rangeslider: RangeSlider(),
      ),
      yaxis: AxisLayout(
        title: 'Milliseconds',
        fixedrange: true,
      ),
      hovermode: 'x',
      autosize: true,
      barmode: 'stack',
      bargap: 0.15,
      bargroupgap: 0.1,
      dragmode: 'pan',
      margin: Margin(
        l: 80,
        r: 0,
        b: 15,
        t: 30,
        pad: 5,
      ),
    );
  }

  static List<Data> createFPSTraces() {
    final Data traceCpuGood = Data(
      y: [],
      x: [],
      type: 'bar',
      stackgroup: 'one',
      name: 'CPU',
      hoverinfo: 'y+name',
      marker: Marker(
        color: cpuColor,
      ),
      width: [0],
    );

    final Data traceGpuGood = Data(
      y: [],
      x: [],
      type: 'bar',
      name: 'GPU',
      hoverinfo: 'y+name',
      marker: Marker(
        color: gpuColor,
      ),
      width: [0],
    );

    final Data traceCpuJank = Data(
      y: [],
      x: [],
      type: 'bar',
      name: 'CPU Jank',
      hoverinfo: 'y+name',
      hoverlabel: HoverLabel(
        font: Font(
          color: 'white',
        ),
        bordercolor: 'rgba(255, 0, 0, .8)',
      ),
      marker: Marker(
        color: cpuColor,
        line: Line(
          color: gpuJankColor,
          width: 2,
        ),
      ),
      width: [0],
    );

    final Data traceGpuJank = Data(
      y: [],
      x: [],
      type: 'bar',
      name: 'GPU Jank',
      hoverinfo: 'y+name',
      hoverlabel: HoverLabel(
        font: Font(color: 'white'),
        bordercolor: 'rgba(255, 0, 0, .7)',
      ),
      marker: Marker(
        color: gpuColor,
        line: Line(
          color: gpuJankColor,
          width: 2,
        ),
      ),
      width: [0],
    );

    // Return in trace index order
    return [
      traceCpuGood,
      traceCpuJank,
      traceGpuGood,
      traceGpuJank,
    ];
  }

  void plotFPS() {
    Plotly.newPlot(
        _domName,
        createFPSTraces(),
        getFPSTimeseriesLayout('Frame Rendering Time'),
        Configuration(
          responsive: true,
          displaylogo: false,
          displayModeBar: false,
        ));
  }

  void plotFPSDatum(
    int dataIndex,
    num cpuDuration,
    num gpuDuration,
    bool paused,
  ) {
    final List<int> traces = [];

    traces.add(cpuDuration > jankMs ? cpuJankTraceIndex : cpuGoodTraceIndex);
    traces.add(gpuDuration > jankMs ? gpuJankTraceIndex : gpuGoodTraceIndex);

    final TraceData data = TraceData(
      x: [
        [dataIndex],
        [dataIndex],
      ],
      y: [
        [cpuDuration],
        [gpuDuration],
      ],
    );

    Plotly.extendTraces(
      _domName,
      data,
      traces,
    );

    if (!paused) rangeSliderToLast(dataIndex);
  }

  // Chunky plotting of data to reduce plotly live charting lag.
  void plotFPSDataList(
    List<int> dataIndexes,
    List<num> cpuDurations,
    List<num> gpuDurations,
    bool paused,
  ) {
    final List<int> cpuGoodX = [];
    final List<num> cpuGoodTrace = [];

    final List<int> cpuJankX = [];
    final List<num> cpuJankTrace = [];

    final List<int> gpuGoodX = [];
    final List<num> gpuGoodTrace = [];

    final List<int> gpuJankX = [];
    final List<num> gpuJankTrace = [];

    final int totalIndexes = dataIndexes.length;
    for (int dataIndex = 0; dataIndex < totalIndexes; dataIndex++) {
      final num cpuDuration = cpuDurations[dataIndex];
      final num gpuDuration = gpuDurations[dataIndex];

      if (cpuDuration > jankMs) {
        cpuJankX.add(dataIndexes[dataIndex]);
        cpuJankTrace.add(cpuDuration);
      } else {
        cpuGoodX.add(dataIndexes[dataIndex]);
        cpuGoodTrace.add(cpuDuration);
      }

      if (gpuDuration > jankMs) {
        gpuJankX.add(dataIndexes[dataIndex]);
        gpuJankTrace.add(gpuDuration);
      } else {
        gpuGoodX.add(dataIndexes[dataIndex]);
        gpuGoodTrace.add(gpuDuration);
      }
    }

    final TraceData data = TraceData(x: [], y: []);
    final List<int> traces = [];
    if (cpuJankX.isNotEmpty) {
      data.x.add(cpuJankX);
      data.y.add(cpuJankTrace);
      traces.add(cpuJankTraceIndex);
    }
    if (cpuGoodX.isNotEmpty) {
      data.x.add(cpuGoodX);
      data.y.add(cpuGoodTrace);
      traces.add(cpuGoodTraceIndex);
    }
    if (gpuJankX.isNotEmpty) {
      data.x.add(gpuJankX);
      data.y.add(gpuJankTrace);
      traces.add(gpuJankTraceIndex);
    }
    if (gpuGoodX.isNotEmpty) {
      data.x.add(gpuGoodX);
      data.y.add(gpuGoodTrace);
      traces.add(gpuGoodTraceIndex);
    }

    // TODO(terry): Eliminate this JS call (result of reified List?).
    myExtendTraces(
      _domName,
      cpuJankX,
      cpuGoodX,
      gpuJankX,
      gpuGoodX,
      cpuJankTrace,
      cpuGoodTrace,
      gpuJankTrace,
      gpuGoodTrace,
      [
        cpuJankTraceIndex,
        cpuGoodTraceIndex,
        gpuJankTraceIndex,
        gpuGoodTraceIndex
      ],
    );

    if (!paused) rangeSliderToLast(dataIndexes.last);
  }

  void rangeSliderToLast(int dataIndex) {
    if (dataIndex > ticksInRangeSlider) {
      Plotly.update(
        _domName,
        Data(),
        Layout(
          xaxis: AxisLayout(
            range: [dataIndex - ticksInRangeSlider, dataIndex],
            rangeslider: RangeSlider(),
          ),
        ),
      );
    }
  }

  void chartClick(String domName, Function f) {
    mouseClick(domName, f);
  }
}
