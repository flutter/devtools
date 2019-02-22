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
  static const int gpuGoodTraceIndex = 1;
  static const int cpuJankTraceIndex = 2;
  static const int gpuJankTraceIndex = 3;

  // Careful if changing this to something other than -1 because of
  // rangemode: nonnegative
  static const int xCoordNotUsed = -1;
  static const int yCoordNotUsed = 0;

  static const int xCoordFirst = 0;

  // Default number of bars displayed in zoom (range slider).
  static const int ticksInRangeSlider = 90;

  final String _domName;

  Layout getFPSTimeseriesLayout() {
    return Layout(
      xaxis: AxisLayout(
        rangeslider: RangeSlider(),
        // TODO(terry): Need ThemedColor for dark theme.
        // Hide ticks by using font color of bgColor.
        tickfont: Font(
          color: 'white',
        ),
        rangemode: 'nonnegative',
        autorange: true,
      ),
      yaxis: AxisLayout(
        title: 'Milliseconds',
        fixedrange: true,
      ),
      hovermode: 'x',
      autosize: true,
      barmode: 'stack',
      dragmode: 'pan',
      margin: Margin(
        l: 80,
        r: 0,
        b: 5,
        t: 5,
        pad: 5,
      ),
    );
  }

  static List<Data> createFPSTraces() {
    // Strange plotly bug with initial setup of x,y.  If x and y are empty array
    // then the first entry, for each trace, isn't rendered but hover does
    // display the Y value.  So prime each trace with some data.  Added
    // at x-axis coord of xCoordNotUsed (-1) (hide rangemode: nonnegative
    // displays at 0 and greater) and y is zero.
    final Data traceCpuGood = Data(
      y: [yCoordNotUsed],
      x: [xCoordNotUsed],
      type: 'bar',
      legendgroup: 'good_group',
      name: 'CPU',
      hoverinfo: 'y+name',
      marker: Marker(
        color: colorToCss(mainCpuColor),
      ),
      width: [0],
    );

    final Data traceGpuGood = Data(
      y: [yCoordNotUsed],
      x: [xCoordNotUsed],
      type: 'bar',
      legendgroup: 'good_group',
      name: 'GPU',
      hoverinfo: 'y+name',
      marker: Marker(
        color: colorToCss(mainGpuColor),
      ),
      width: [0],
    );

    final Data traceCpuJank = Data(
      y: [yCoordNotUsed],
      x: [xCoordNotUsed],
      type: 'bar',
      legendgroup: 'jank_group',
      name: 'CPU Jank',
      hoverinfo: 'y+name',
      hoverlabel: HoverLabel(
        font: Font(
          // TODO(terry): font color needs be be a ThemedColor.
          color: 'white',
        ),
        bordercolor: colorToCss(hoverJankColor),
      ),
      marker: Marker(
        color: colorToCss(cpuJankColor),
      ),
      width: [0],
    );

    final Data traceGpuJank = Data(
      y: [yCoordNotUsed],
      x: [xCoordNotUsed],
      type: 'bar',
      legendgroup: 'jank_group',
      name: 'GPU Jank',
      hoverinfo: 'y+name',
      hoverlabel: HoverLabel(
        // TODO(terry): font color needs be be a ThemedColor.
        font: Font(color: 'black'),
        bordercolor: colorToCss(hoverJankColor),
      ),
      marker: Marker(
        color: colorToCss(gpuJankColor),
      ),
      width: [0],
    );

    // Return in trace index order
    return [
      traceCpuGood,
      traceGpuGood,
      traceCpuJank,
      traceGpuJank,
    ];
  }

  void plotFPS() {
    Plotly.newPlot(
        _domName,
        createFPSTraces(),
        getFPSTimeseriesLayout(),
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
      cpuGoodX,
      gpuGoodX,
      cpuJankX,
      gpuJankX,
      cpuGoodTrace,
      gpuGoodTrace,
      cpuJankTrace,
      gpuJankTrace,
      [
        cpuGoodTraceIndex,
        gpuGoodTraceIndex,
        cpuJankTraceIndex,
        gpuJankTraceIndex,
      ],
    );

    if (!paused) rangeSliderToLast(dataIndexes.last);
  }

  void rangeSliderToLast(int dataIndex) {
    Plotly.update(
      _domName,
      [Data()],
      Layout(
        xaxis: AxisLayout(
          // TODO(terry): Need ThemedColor for dark theme too.
          // Hide ticks by using font color of bgColor as we slide.
          tickfont: Font(
            color: 'white',
          ),
          rangemode: 'nonnegative',
          range: [dataIndex - ticksInRangeSlider, dataIndex],
          rangeslider: RangeSlider(
            rangemode: 'nonnegative',
            autorange: true,
          ),
        ),
      ),
    );
  }

  void chartClick(String domName, Function f) {
    mouseClick(domName, f);
  }

  void chartHover(String domName, Function f) {
    hoverOver(domName, f);
  }

  void chartLegendClick(String domName, Function f) {
    legendClick(domName, f);
  }
}
