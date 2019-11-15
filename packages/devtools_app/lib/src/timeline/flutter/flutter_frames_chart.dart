// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:mp_chart/mp/chart/bar_chart.dart';
import 'package:mp_chart/mp/controller/bar_chart_controller.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data_set/bar_data_set.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/enums/limite_label_postion.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/limit_line.dart';
import 'package:mp_chart/mp/core/marker/line_chart_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/default_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

class FlutterFramesChart extends StatefulWidget {
  const FlutterFramesChart();

  @override
  FlutterFramesChartState createState() => FlutterFramesChartState();
}

class FlutterFramesChartState extends State<FlutterFramesChart>
    implements OnChartValueSelectedListener {
  BarChartController _chartController;

  BarChartController get chartController => _chartController;

  /// Index into the raw data.
  int timerDataIndex;

  /// Active timer running.
  Timer _timer;

  /// Datapoint entry for each frame duration (UI/GPU) for stacked bars.
  final List<BarEntry> _frameDurations = <BarEntry>[];

  /// Set of all duration information (the data, colors, etc).
  BarDataSet frameDurationsSet;

  @override
  void initState() {
    _initController();

    // True simulates charting a live feed, false to chart all canned data immediately.
    _initData(true);

    super.initState();
  }

  final lightTypeFace = TypeFace(
    fontFamily: 'OpenSans',
    fontWeight: FontWeight.w100,
  );

  final boldTypeFace = TypeFace(
    fontFamily: 'OpenSans',
    fontWeight: FontWeight.w800,
  );

  final double groupSpace = 0.04;
  final double barSpace = 0.0;

  void _initController() {
    final desc = Description()..enabled = false;
    _chartController = BarChartController(
      axisLeftSettingFunction: (axisLeft, controller) {
        axisLeft
          ..typeface = lightTypeFace
          ..drawGridLines = false
          ..setStartAtZero(true)
          ..setValueFormatter(YAxisUnitFormatter())
          ..addLimitLine(LimitLine(60, '60 FPS')
            // TODO(terry): LEFT_TOP is clipped need to fix in MPFlutterChart.
            ..labelPosition = LimitLabelPosition.RIGHT_TOP
            ..textSize = 10
            ..typeface = boldTypeFace
            // TODO(terry): Below crashed Flutter.
            // ..enableDashedLine(5, 5, 0)
            ..lineColor = const Color.fromARGB(0x80, 0xff, 0x44, 0x44));
      },
      axisRightSettingFunction: (axisRight, controller) {
        axisRight.enabled = false;
      },
      xAxisSettingFunction: (XAxis xAxis, controller) {
        xAxis.enabled = true;
        xAxis.drawLabels = true;
        xAxis.setLabelCount1(3);
        xAxis.position = XAxisPosition.BOTTOM;
      },
      legendSettingFunction: (legend, controller) {
        legend.enabled = false;
      },
      drawGridBackground: false,
//      dragXEnabled: true,
//      dragYEnabled: true,
//      scaleXEnabled: true,
//      scaleYEnabled: true,
//      pinchZoomEnabled: false,
//      maxVisibleCount: 60,
      drawBarShadow: false,
      description: desc,
      highLightPerTapEnabled: true,
      marker: SelectedDataPoint(onSelected: frameSelected),
      selectionListener: this,
    );

    // Compute padding around chart.
    _chartController.setViewPortOffsets(50, 10, 10, 30);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void frameSelected(int frameIndex) {
    print('Bar Charted item selected frame index = $frameIndex');
  }

  /// Light Blue 50 - 200
  static const mainUiColorLight = Color.fromARGB(0xff, 0x81, 0xD4, 0xFA);

  /// Light Blue 50 - 700
  static const mainGpuColorLight = Color.fromARGB(0xFF, 0x02, 0x88, 0xD1);

  void _initData([bool simulateFeed = false]) {
    // Prime the dataset with the first entry.  A missing entry will cause a failure
    // with a NAN.
    _frameDurations.add(createBarEntry(0));

    if (!simulateFeed) {
      _loadAllData(3);
    } else if (_timer == null) {
      _startFeed(3);
    } else {
      return;
    }

    // Create heap used dataset.
    frameDurationsSet = BarDataSet(_frameDurations, 'Durations')
      ..setColors1([mainGpuColorLight, mainUiColorLight])
      ..setDrawValues(false);

    // Create a data object with all the data sets - stacked bar.
    _chartController.data = BarData([]..add(frameDurationsSet));

    // specify the width each bar should have
    _chartController.data.barWidth = 0.8;
  }

  // TODO(terry): Consider grouped bars (UI/GPU) not stacked.
  BarEntry createBarEntry(int index) {
    assert(index < _cannedData.length);
    final x = _cannedData[index].toDouble();
    final uiDurationValue = _cannedData[index + 1].toDouble();
    final gpuDurationValue = _cannedData[index + 2].toDouble();

    // TODO(terry): Structured class item 0 is GPU, item 1 is UI if not stacked.
    return BarEntry.fromListYVals(
      x: x,
      vals: [
        gpuDurationValue,
        uiDurationValue,
      ],
    );
  }

  /// Simulate live feed.
  void _startFeed(int startIndex) {
    // Fetch from the beginning of the canned data for the live feed.
    timerDataIndex = startIndex; // Entry zero is already primed.

    // TODO(terry): Consider moving the timer to the MemoryController.
    // TODO(terry): The chart should be notified when new data arrives from the controller
    //              using a notifier pattern.
    // Average VMSerice rate is ~500-600 ms?
    _timer = Timer.periodic(const Duration(milliseconds: 60), (Timer timer) {
      if (timerDataIndex == 0) {
        // First time reset our plotted data.
        setState(() {
          _frameDurations.clear();
        });
      }

      // Keep pumping out data, simulating a live feed.
      if (timerDataIndex < _cannedData.length) {
        _frameDurations.add(createBarEntry(timerDataIndex));
        timerDataIndex += 3;
      }

      _updateChart();
    });
  }

  void _updateChart() {
    _chartController.data = BarData([]..add(frameDurationsSet));

    setState(() {
      // Signal data has changed.
      frameDurationsSet.notifyDataSetChanged();
    });
  }

  void _loadAllData(int startIndex) {
    int index = startIndex;
    while (index < _cannedData.length) {
      _frameDurations.add(createBarEntry(index));
      index += 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200.0,
      child: BarChart(_chartController),
    );
  }

  /// OnChartValueSelectedListener override.
  @override
  void onNothingSelected() {
    print('Nothing Selected');
  }

  /// OnChartValueSelectedListener override.
  @override
  void onValueSelected(Entry e, Highlight h) {
    // TODO(terry): Either use onTouchDown or add mouse position to laggy.
    final yValues = (e as BarEntry).yVals;
    print(
      'onValueSelected - Frame Index = ${e.x}, '
      'GPU = ${yValues[0]}, UI = ${yValues[1]}',
    );
  }
}

class YAxisUnitFormatter extends ValueFormatter {
  @override
  String getFormattedValue1(double value) => '${value.toInt()} ms';
}

typedef SelectionCallback = void Function(int frameIndex);

/// Selection of a point in the Bar chart displays the data point values
/// UI duration and GPU duration. Also, highlight the selected stacked bar.
/// Uses marker/highlight mechanism which lags because it uses onTapUp maybe
/// onTapDown would be less laggy.
///
/// TODO(terry): Highlighting is not efficient, a faster mechanism to return
/// the Entry being clicked is needed.
///
/// onSelected callback function invoked when bar entry is selected.
class SelectedDataPoint extends LineChartMarker {
  SelectedDataPoint({
    this.textColor,
    this.backColor,
    this.fontSize,
    this.onSelected,
  }) {
    _formatter = DefaultValueFormatter(2);
    textColor ??= ColorUtils.WHITE;
    backColor ??= const Color.fromARGB(127, 0, 0, 0);
    fontSize ??= 10;
  }

  Entry _entry;

  DefaultValueFormatter _formatter;

  Color textColor;

  Color backColor;

  double fontSize;

  int _lastFrameIndex = -1;

  final SelectionCallback onSelected;

  @override
  void draw(Canvas canvas, double posX, double posY) {
    const positionAboveBar = 15;
    const paddingAroundText = 5;
    const rectangleCurve = 5.0;

    final frameIndex = _entry.x.toInt();
    final yValues = (_entry as BarEntry).yVals;

    final num uiDuration = yValues[1];
    final num gpuDuration = yValues[0];

    final TextPainter painter = PainterUtils.create(
      null,
      'UI  = ${_formatter.getFormattedValue1(uiDuration)}\n'
      'GPU = ${_formatter.getFormattedValue1(gpuDuration)}',
      textColor,
      fontSize,
    )..textAlign = TextAlign.left;

    final Paint paint = Paint()
      ..color = backColor
      ..strokeWidth = 2
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final MPPointF offset = getOffsetForDrawingAtPoint(
      posX,
      posY,
    );

    canvas.save();
    // translate to the correct position and draw
    painter.layout();
    final Offset pos = calculatePos(
      posX + offset.x,
      posY + offset.y - positionAboveBar,
      painter.width,
      painter.height,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        pos.dx - paddingAroundText,
        pos.dy - paddingAroundText,
        pos.dx + painter.width + paddingAroundText,
        pos.dy + painter.height + paddingAroundText,
        const Radius.circular(rectangleCurve),
      ),
      paint,
    );
    painter.paint(canvas, pos);
    canvas.restore();

    if (onSelected != null && _lastFrameIndex != frameIndex) {
      // Only fire when a different frame is selected.
      onSelected(frameIndex);
      _lastFrameIndex = frameIndex;
    }
  }

  @override
  void refreshContent(Entry e, Highlight highlight) {
    _entry = e;
  }
}

/// Format is frameIndex, UIDuration, GPUDuration.
const List _cannedData = [
  0,
  3.218,
  36.549,
  1,
  1.305,
  57.595,
  2,
  1.028,
  98.058,
  3,
  0.86,
  80.463,
  4,
  1.264,
  66.55,
  5,
  0.98,
  74.376,
  6,
  1.185,
  77.766,
  7,
  0.907,
  86.637,
  8,
  1.255,
  60.998,
  9,
  1.155,
  99.481,
  10,
  1.065,
  144.511,
  11,
  0.909,
  64.112,
  12,
  11.175,
  85.209,
  13,
  15.582,
  67.938,
  14,
  1.108,
  67.9,
  15,
  1.481,
  138.497,
  16,
  14.96,
  63.428,
  17,
  3.004,
  121.087,
  18,
  4.804,
  38.031,
  19,
  1.745,
  52.475,
  20,
  3.64,
  81.454,
  21,
  3.732,
  142.789,
  22,
  2.001,
  50.509,
  23,
  2.736,
  72.711,
  24,
  1.345,
  92.692,
  25,
  0.925,
  132.785,
  26,
  1.425,
  51.298,
  27,
  1.055,
  87.561,
  28,
  0.995,
  98.082,
  29,
  1.714,
  86.122,
  30,
  0.876,
  63.85,
  31,
  0.764,
  68.218,
  32,
  10.903,
  68.551,
  33,
  1.246,
  47.459,
  34,
  2.229,
  59.701,
  35,
  43.814,
  71.36,
  36,
  5.911,
  161.087,
  37,
  15.062,
  99.264,
  38,
  5.194,
  102.166,
  39,
  7.122,
  69.807,
  40,
  4.863,
  43.422,
  41,
  44.468,
  34.283,
  42,
  4.699,
  134.304,
  43,
  2.633,
  59.456,
  44,
  2.232,
  129.259,
  45,
  2.697,
  55.589,
  46,
  58.158,
  78.779,
  47,
  13.521,
  43.724,
  48,
  2.817,
  62.059,
  49,
  2.283,
  93.432,
  50,
  7.955,
  111.559,
  51,
  4.465,
  74.337,
  52,
  7.382,
  94.728,
  53,
  10.683,
  87.745,
  54,
  7.214,
  39.637,
  55,
  5.193,
  36.368,
  56,
  6.807,
  83.566,
  57,
  5.911,
  73.927,
  58,
  1.379,
  71.415,
  59,
  1.142,
  147.572,
  60,
  1.304,
  44.442,
  61,
  1.125,
  80.785,
  62,
  1.241,
  69.388,
  63,
  1.452,
  64.649,
  64,
  1.071,
  79.852,
  65,
  1.436,
  83.529,
  66,
  1.134,
  86.381,
  67,
  3.59,
  44.315,
  68,
  1.941,
  45.718,
  69,
  1.342,
  86.342,
  70,
  5.263,
  82.836,
  71,
  11.112,
  114.19,
  72,
  4.821,
  78.728,
  73,
  4.531,
  75.169,
  74,
  5.799,
  73.861,
  75,
  1.526,
  53.72,
  76,
  1.217,
  35.327,
  77,
  32.193,
  72.671,
  78,
  4.172,
  125.424,
  79,
  1.686,
  71.494,
  80,
  1.788,
  107.995,
  81,
  4.726,
  70.006,
  82,
  0.884,
  81.594,
  83,
  2.825,
  38.357,
  84,
  27.72,
  44.586,
  85,
  7.222,
  133.237,
  86,
  2.66,
  62.544,
  87,
  1.991,
  153.551,
  88,
  1.697,
  66.444,
  89,
  33.478,
  82.867,
  90,
  11.731,
  66.318,
  91,
  2.224,
  89.243,
  92,
  2.605,
  91.943,
  93,
  1.53,
  39.063,
  94,
  6.165,
  120.09,
  95,
  4.132,
  49.72,
  96,
  3.4,
  59.575,
  97,
  8.97,
  101.729,
  98,
  1.778,
  56.297,
  99,
  2.556,
  117.509,
  100,
  2.002,
  63.826,
  101,
  1.586,
  139.164,
  102,
  1.745,
  67.09,
  103,
  1.871,
  82.303,
  104,
  2.318,
  102.108,
  105,
  1.902,
  85.11,
  106,
  1.554,
  70.975,
  107,
  1.6,
  94.618,
  108,
  29.467,
  51.69,
  109,
  8.409,
  123.735,
  110,
  2.74,
  119.423,
];
