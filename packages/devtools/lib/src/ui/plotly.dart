// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library plotly;

import 'package:js/js.dart';

// Button names for modeBarButtonsToRemove
const String sendDataToClose = 'sendDataToCloud';
const String select2D = 'select2d';
const String lasso2D = 'lasso2d';
const String hoverClosestCartesian = 'hoverClosestCartesian';
const String hoverCompareCartesian = 'hoverCompareCartesian';
const String toggleSpikeLines = 'toggleSpikelines';

@JS('hookupPlotlyClick')
external void _hookupPlotlyClick(
  String domName,
  Function jsFunction,
);

@JS()
external void myExtendTraces(
  String domName,
  List x0,
  List x1,
  List x2,
  List x3,
  List y0,
  List y1,
  List y2,
  List y3,
  List traces,
);

@JS()
class Plotly {
  external static void newPlot(
    String domName,
    List<Data> traces, [
    Layout layout,
    Configuration config,
  ]);
  external static void extendTraces(
    String domName,
    TraceData traceData,
    List<int> traceindex,
  );
  external static void update(
    String domName,
    Data data,
    Layout layout, [
    List<int> traceindex,
  ]);
}

@JS()
@anonymous
class TraceData {
  external factory TraceData({
    List<List> x,
    List<List> y,
  });

  external List<List> get x;
  external List<List> get y;
}

@JS()
@anonymous
class Data {
  external factory Data({
    List x,
    List y,
    String type,
    String mode,
    Marker marker,
    Line line,
    String name,
    List<String> text,
    String stackgroup,
    List<Transform> transforms,
    String hoverinfo,
    HoverLabel hoverlabel,
    bool showlegend,
    String legendgroup,
    List<int> width,
  });

  external List get x;
  external List get y;
  external String get type;
  external String get mode;
  external Marker get marker;
  external Line get line;
  external String get name;
  external List<String> get text;
  external String get stackgroup;
  external List<Transform> get transforms;
  external String get hoverinfo;
  external HoverLabel get hoverlabel;
  external bool get showlegend;
  external String get legendgroup;
  external List<int> get width;
}

@JS()
@anonymous
class Marker {
  external factory Marker({
    String color,
    String symbol,
    int size,
    Line line,
  });

  external String get color;
  external String get symbol;
  external int get size;
  external Line get line;
}

@JS()
@anonymous
class Line {
  external factory Line({
    String color,
    String dash,
    int width,
  });

  external String get color;
  external String get dash;
  external int get width;
}

@JS()
@anonymous
class Transform {
  external factory Transform({
    List target,
    bool enabled,
    bool preservegaps,
    String operation,
    int value,
    String type,
  });

  external List get target;
  external bool get enabled;
  external bool get preservegaps;
  external String get operation;
  external int get value;
  external String get type;
}

@JS()
@anonymous
class Layout {
  external factory Layout({
    String title,
    bool showlegend,
    AxisLayout xaxis,
    AxisLayout yaxis,
    bool autosize,
    Margin margin,
    String hovermode,
    String barmode,
    num bargap,
    num bargroupgap,
    String dragmode,
    HoverLabel hoverlabel,
  });

  external String get title;
  external bool get showlegend;
  external AxisLayout get xaxis;
  external AxisLayout get yaxis;
  external bool get autosize;
  external Margin get margin;
  external String get hovermode;
  external bool get barmode;
  external num get bargap;
  external num get bargroupgap;
  external String get dragmode;
}

@JS()
@anonymous
class HoverLabel {
  external factory HoverLabel({
    String bgcolor,
    String bordercolor,
    Font font,
  });

  external String get bgcolor;
  external String get bordercolor;
  external Font get font;
}

@JS()
@anonymous
class Font {
  external factory Font({
    String family,
    String color,
    int size,
  });

  external String get family;
  external String get color;
  external int get size;
}

@JS()
@anonymous
class AxisLayout {
  external factory AxisLayout({
    String tickformat,
    String ticks,
    String title,
    bool fixedrange,
    String type,
    bool autorange,
    String rangemode,
    List<num> range,
    RangeSlider rangeslider,
    RangeSelector rangeselector,
    bool showgrid,
    bool showticklabels,
  });

  external String get tickformat;
  external String get ticks;
  external String get title;
  external bool get fixedrange;
  external String get type;
  external bool get autorange;
  external String get rangemode;
  external List<num> get range;
  external RangeSlider get rangeslider;
  external RangeSelector get rangeselector;
  external bool get showgrid;
  external bool get showticklabels;
}

@JS()
@anonymous
class RangeSelector {
  external factory RangeSelector({
    List<Button> buttons,
  });

  external List<Button> get buttons;
}

@JS()
@anonymous
class Button {
  external factory Button({
    int count,
    String label,
    String step,
    String stepmode,
  });

  external int get count;
  external String get label;
  external String get step;
  external String get stepmode;
}

@JS()
@anonymous
class Margin {
  external factory Margin({
    int l,
    int r,
    int b,
    int t,
    int pad,
  });

  external int get l;
  external int get r;
  external int get b;
  external int get t;
  external int get pad;
}

@JS()
@anonymous
class RangeSlider {
  external factory RangeSlider({
    String bgcolor,
    String bordercolor,
    int borderwidth,
    bool autorange,
    List<num> range,
    num thickness,
    bool visible,
    String rangemode,
  });

  external String get bgcolor;
  external String get bordercolor;
  external int get borderwidth;
  external bool get autorange;
  external List<num> get range;
  external num get thickness;
  external bool get visible;
  external String get rangemode;
}

@JS()
@anonymous
class Configuration {
  external factory Configuration({
    bool displayModeBar,
    bool responsive,
    bool displaylogo,
    List<String> modeBarButtonsToRemove,
  });

  external bool get displayModeBar;
  external bool get responsive;
  external bool get displaylogo;
  external List<String> get modeBarButtonsToRemove;
}

@JS()
@anonymous
class DataEvent {
  external dynamic get event;
  external List<Point> get points;
}

@JS()
@anonymous
class Point {
  external factory Point({
    int curveNumber,
    List<Data> data,
    int pointIndex,
    int pointNumber,
    AxisLayout xaxis,
    AxisLayout yaxis,
    num x,
    num y,
  });

  external int get curveNumber;
  external List<Data> get data;
  external int get pointIndex;
  external int get pointNumber;
  external AxisLayout get xaxis;
  external AxisLayout get yaxis;
  external num get x;
  external num get y;
}

void mouseClick(
  String domName,
  Function f,
) {
  // Hookup clicks in the plotly chart.
  _hookupPlotlyClick(domName, allowInterop(f));
}
