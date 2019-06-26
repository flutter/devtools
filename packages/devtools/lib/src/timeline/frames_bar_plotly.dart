// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:js/js_util.dart';

import '../ui/colors.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/plotly.dart';
import '../ui/theme.dart';

class FramesBarPlotly {
  FramesBarPlotly(
    this._domName,
    this._chart, {
    this.useLogScale = true,
    this.showRangeSlider = true,
  });

  // Any duration of ui/gpu greater than 8 ms is a jank.
  static const double jankthresholdMs = 1000.0 / 60.0;

  static const int gpuGoodTraceIndex = 0;
  static const int gpuSelectTraceIndex = 1;
  static const int uiGoodTraceIndex = 2;
  static const int uiSelectTraceIndex = 3;

  // IMPORTANT: Last trace need to update numberOfTraces constant below.

  // Compute total number of traces in graph.
  static const int numberOfTraces = uiSelectTraceIndex + 1;

  // Any point in our frame chart is in only two traces.  The gpu duration will
  // be in either gpu good or gpu jank trace.  The ui duration will be in
  // either ui good or ui jank trace.  The only exception is a select bar that
  // will be in gpu selection and ui selection traces.
  static const int activeTracesPerX = 2;

  // Careful if changing this to something other than -1 because of
  // rangemode: nonnegative
  static const int xCoordNotUsed = -1;
  static const int yCoordNotUsed = 0;

  static const int xCoordFirst = 0;

  // Default number of bars displayed in zoom (range slider).
  static const int ticksInRangeSlider = 90;

  final String _domName;
  final dynamic _chart;
  final bool useLogScale;
  final bool showRangeSlider;

  final _yAxisLogScale = AxisLayout(
    title: Title(
      text: 'Milliseconds',
    ),
    tickformat: '.0f',
    type: 'log',
    range: [0, 2],
    nticks: 10,
    titlefont: Font(color: colorToCss(defaultForeground)),
    tickfont: Font(color: colorToCss(defaultForeground)),
    tickmode: 'array',
    tickvals: [
      1,
      10,
      100,
    ],
    ticktext: [
      1,
      10,
      100,
    ],
    hoverformat: '.3f',
    showgrid: false,
  );

  final _yAxisLinearScale = AxisLayout(
    title: Title(
      text: 'Milliseconds',
    ),
    titlefont: Font(color: colorToCss(defaultForeground)),
    tickfont: Font(color: colorToCss(defaultForeground)),
    fixedrange: true,
  );

  Layout getFPSTimeseriesLayout() {
    return Layout(
      plot_bgcolor: colorToCss(chartBackground),
      paper_bgcolor: colorToCss(chartBackground),
      legend: Legend(font: Font(color: colorToCss(defaultForeground))),
      xaxis: AxisLayout(
        rangeslider: showRangeSlider ? RangeSlider() : null,
        // Hide ticks by using font color of bgColor.
        tickfont: Font(
          color: colorToCss(chartBackground),
          size: 1,
        ),
        rangemode: 'nonnegative',
        autorange: true,
      ),
      yaxis: useLogScale ? _yAxisLogScale : _yAxisLinearScale,
      hovermode: 'x',
      autosize: true,
      barmode: 'stack',
      dragmode: 'pan',
      shapes: [
        Shape(
          type: 'line',
          xref: 'paper',
          layer: 'below',
          x0: 0,
          y0: jankthresholdMs,
          x1: 1,
          y1: jankthresholdMs,
          line: Line(
            dash: 'dot',
            color: colorToCss(highwater16msColor),
            width: 1,
          ),
        ),
      ],
      margin: Margin(
        l: 60,
        r: 0,
        b: 8,
        t: 5,
        pad: 8,
      ),
    );
  }

  // Return a list of all of traces in trace index order:
  // e.g., [
  //         GPU Good Trace Data,   // array index gpuGoodTraceIndex
  //         GPU Jank Trace Data,   // array index gpuJankTraceIndex
  //         GPU Select Trace Data, // array index gpuSelectTraceIndex
  //         UI Good Trace Data,   // array index uiGoodTraceIndex
  //         UI Jank Trace Data,   // array index uiJankTraceIndex
  //         UI Select Trace Data, // array index uiSelectTraceIndex
  //       ]
  static List<Data> createFPSTraces() {
    final List<Data> allTraces = [];

    // Strange plotly bug with initial setup of x,y.  If x and y are empty array
    // then the first entry, for each trace, isn't rendered but hover does
    // display the Y value.  So prime each trace with some data.  Added
    // at x-axis coord of xCoordNotUsed (-1) (hide rangemode: nonnegative
    // displays at 0 and greater) and y is zero.

    // trace GPU Good
    allTraces.insert(
      gpuGoodTraceIndex,
      Data(
        y: [yCoordNotUsed],
        x: [xCoordNotUsed],
        type: 'bar',
        name: 'GPU',
        hoverinfo: 'y+name',
        hoverlabel: HoverLabel(
          font: Font(
            color: colorToCss(hoverTextColor),
          ),
        ),
        marker: Marker(
          color: colorToCss(mainGpuColor),
        ),
        width: [0],
      ),
    );

    // trace GPU Select
    allTraces.insert(
      gpuSelectTraceIndex,
      Data(
        y: [yCoordNotUsed],
        x: [xCoordNotUsed],
        hoverinfo: 'y+name',
        hoverlabel: HoverLabel(
          bgcolor: colorToCss(selectedGpuColor),
          font: Font(
            color: colorToCss(hoverTextColor),
          ),
          bordercolor: colorToCss(selectedGpuColor),
        ),
        showlegend: false,
        type: 'bar',
        marker: Marker(
          color: colorToCss(selectedGpuColor),
        ),
      ),
    );

    // trace UI Good
    allTraces.insert(
      uiGoodTraceIndex,
      Data(
        y: [yCoordNotUsed],
        x: [xCoordNotUsed],
        type: 'bar',
        name: 'UI',
        hoverinfo: 'y+name',
        hoverlabel: HoverLabel(
          font: Font(
            color: colorToCss(hoverTextColor),
          ),
        ),
        marker: Marker(
          color: colorToCss(mainUiColor),
        ),
        width: [0],
      ),
    );

    // trace UI Select
    allTraces.insert(
      uiSelectTraceIndex,
      Data(
        y: [yCoordNotUsed],
        x: [xCoordNotUsed],
        hoverinfo: 'y+name',
        hoverlabel: HoverLabel(
          bgcolor: colorToCss(selectedUiColor),
          font: Font(
            color: colorToCss(hoverTextColor),
          ),
          bordercolor: colorToCss(selectedUiColor),
        ),
        showlegend: false,
        type: 'bar',
        marker: Marker(
          color: colorToCss(selectedUiColor),
        ),
      ),
    );

    assert(allTraces.length == numberOfTraces);

    return allTraces;
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
      ),
    );
  }

  // Chunky plotting of data to reduce plotly live charting lag.
  void plotFPSDataList(
    List<int> dataIndexes,
    List<num> uiDurations,
    List<num> gpuDurations,
    bool paused,
  ) {
    final List<int> uiGoodX = [];
    final List<num> uiGoodTrace = [];

    final List<int> gpuGoodX = [];
    final List<num> gpuGoodTrace = [];

    final int totalIndexes = dataIndexes.length;
    for (int dataIndex = 0; dataIndex < totalIndexes; dataIndex++) {
      final num uiDuration = uiDurations[dataIndex];
      final num gpuDuration = gpuDurations[dataIndex];

      uiGoodX.add(dataIndexes[dataIndex]);
      uiGoodTrace.add(uiDuration);
      gpuGoodX.add(dataIndexes[dataIndex]);
      gpuGoodTrace.add(gpuDuration);

      if (uiDuration + gpuDuration > jankthresholdMs) {
        glowBarFrame(dataIndexes[dataIndex], uiDuration + gpuDuration);
      }
    }

    final TraceData data = TraceData(x: [], y: []);
    final List<int> traces = [];
    if (uiGoodX.isNotEmpty) {
      data.x.add(uiGoodX);
      data.y.add(uiGoodTrace);
      traces.add(uiGoodTraceIndex);
    }
    if (gpuGoodX.isNotEmpty) {
      data.x.add(gpuGoodX);
      data.y.add(gpuGoodTrace);
      traces.add(gpuGoodTraceIndex);
    }

    // TODO(terry): Eliminate this JS call (result of reified List?).
    extendTraces2(
      _domName,
      uiGoodX,
      gpuGoodX,
      uiGoodTrace,
      gpuGoodTrace,
      [uiGoodTraceIndex, gpuGoodTraceIndex],
    );

    if (!paused) rangeSliderToLast(dataIndexes.last + 1);
  }

  void rangeSliderToLast(int dataIndex) {
    Plotly.update(
      _domName,
      [Data()],
      Layout(
        xaxis: AxisLayout(
          // Hide ticks by using font color of bgColor as we slide.
          tickfont: Font(color: colorToCss(chartBackground)),
          rangemode: 'nonnegative',
          range: [dataIndex - ticksInRangeSlider, dataIndex],
          rangeslider: showRangeSlider
              ? RangeSlider(rangemode: 'nonnegative', autorange: true)
              : null,
        ),
      ),
    );
  }

  void glowBarFrame(num x, num height) {
    final Layout layout = getProperty(_chart, 'layout');
    final List<Shape> shapes = layout.shapes;

    final int nextShape = shapes.length;

    final jsShape = createGlowShape(
      nextShape,
      x,
      height,
      colorToCss(jankGlowInside),
      colorToCss(jankGlowEdge),
    );
    Plotly.relayout(_domName, jsShape);
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

class SelectTrace {
  SelectTrace(
    this.traceIndex,
    this.ptNumber,
    this.xValue,
    this.yValue,
  );

  final int traceIndex;
  int ptNumber;
  final num xValue;
  final num yValue;
}

class Selection {
  Selection(
    this._domName,
    dynamic graphDiv,
  ) : _data = getProperty(graphDiv, 'data');

  final String _domName;
  final List<Data> _data;
  List<SelectTrace> selectInfo = [];

  bool isSelected(List<SelectTrace> newSelection) =>
      selectInfo.length == FramesBarPlotly.activeTracesPerX &&
      selectInfo[0].xValue == newSelection[0].xValue &&
      selectInfo[1].xValue == newSelection[1].xValue;

  int get selectedPointNumber =>
      selectInfo.isNotEmpty ? selectInfo[0].ptNumber : -1;

  void select(List<SelectTrace> newSelection) {
    // Supports one bar selection and not selecting a currently selected bar.
    assert(newSelection.length == FramesBarPlotly.activeTracesPerX &&
        newSelection[0].traceIndex != FramesBarPlotly.gpuSelectTraceIndex &&
        newSelection[1].traceIndex != FramesBarPlotly.uiSelectTraceIndex);

    final List<SelectTrace> oldSelectInfo = unselect();

    // Maybe adjust our current pointNumbers (plotly term is an array index
    // into data). If we messed with a trace and the old pointNumbers was before
    // our new bar we need to adjust.
    if (oldSelectInfo.isNotEmpty) {
      final int oldTrace0 = oldSelectInfo[0].traceIndex;
      final int oldPtNum0 = oldSelectInfo[0].ptNumber;
      final int oldTrace1 = oldSelectInfo[1].traceIndex;
      final int oldPtNum1 = oldSelectInfo[1].ptNumber;

      final int newTrace0 = newSelection[0].traceIndex;
      final int newPtNum0 = newSelection[0].ptNumber;
      final int newTrace1 = newSelection[1].traceIndex;
      final int newPtNum1 = newSelection[1].ptNumber;

      // After unselecting, the old selection data is restored back to our
      // traces (gpu good/jank and UI good/jank) from the selection traces.
      // Adjust the newSelection pointNumbers to point to the new location of
      // the real data after unselect.
      if (oldTrace0 == newTrace0 && newPtNum0 >= oldPtNum0) {
        newSelection[0].ptNumber += 1;
      }
      if (oldTrace1 == newTrace1 && newPtNum1 >= oldPtNum1) {
        newSelection[1].ptNumber += 1;
      }
    }

    // This is our new current selection.
    selectInfo = newSelection;

    // Make room for our selection bar remove the data we're selecting it will
    // exist in the selection traces.
    for (var selectTrace in selectInfo) {
      _data[selectTrace.traceIndex].x.removeAt(selectTrace.ptNumber);
      _data[selectTrace.traceIndex].y.removeAt(selectTrace.ptNumber);
    }

    // Move the data to the selection traces.
    extendTraces2(_domName, [
      selectInfo[0].xValue,
    ], [
      selectInfo[1].xValue,
    ], [
      selectInfo[0].yValue,
    ], [
      selectInfo[1].yValue,
    ], [
      FramesBarPlotly.gpuSelectTraceIndex,
      FramesBarPlotly.uiSelectTraceIndex,
    ]);

    // Construct the hover names for each selection trace.
    final String gpuSelectionHoverName =
        selectInfo[0].traceIndex == FramesBarPlotly.gpuGoodTraceIndex
            ? 'GPU'
            : 'GPU Jank';
    final String uiSelectionHoverName =
        selectInfo[1].traceIndex == FramesBarPlotly.uiGoodTraceIndex
            ? 'UI'
            : 'UI Jank';

    // Update the hovers for the selection traces.
    Plotly.restyle(
      _domName,
      'name',
      [gpuSelectionHoverName],
      [FramesBarPlotly.gpuSelectTraceIndex],
    );
    Plotly.restyle(
      _domName,
      'name',
      [uiSelectionHoverName],
      [FramesBarPlotly.uiSelectTraceIndex],
    );
  }

  /// Unselect the current bar in the selection traces. Then restore the data
  /// point in the gpu good/jank and UI good/jank trace.
  ///
  /// Returns the old selectionInfo of empty list if no selection.
  List<SelectTrace> unselect() {
    if (selectInfo.isNotEmpty) {
      for (var selectTrace in selectInfo) {
        final int trace = selectTrace.traceIndex;
        final int ptNumber = selectTrace.ptNumber;
        final num xValue = selectTrace.xValue;
        final num yValue = selectTrace.yValue;

        // Restore our data point (selected) back to traces (gpu good/jank &
        // UI good/jank).
        _data[trace].x.insert(ptNumber, xValue);
        _data[trace].y.insert(ptNumber, yValue);
      }

      // Remove all trace selection data.
      _data[FramesBarPlotly.gpuSelectTraceIndex].x.removeAt(1);
      _data[FramesBarPlotly.gpuSelectTraceIndex].y.removeAt(1);
      _data[FramesBarPlotly.uiSelectTraceIndex].x.removeAt(1);
      _data[FramesBarPlotly.uiSelectTraceIndex].y.removeAt(1);

      final List<SelectTrace> oldSelectInfo = [];
      oldSelectInfo.add(selectInfo[0]);
      oldSelectInfo.add(selectInfo[1]);

      selectInfo = [];

      return oldSelectInfo;
    }

    return [];
  }
}
