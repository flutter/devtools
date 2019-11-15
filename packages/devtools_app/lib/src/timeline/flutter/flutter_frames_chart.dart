// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

import '../../flutter/controllers.dart';
import '../../ui/fake_flutter/_real_flutter.dart';
import '../timeline_controller.dart';
import '../timeline_model.dart';

class FlutterFramesChart extends StatefulWidget {
  const FlutterFramesChart();

  @override
  _FlutterFramesChartState createState() => _FlutterFramesChartState();
}

class _FlutterFramesChartState extends State<FlutterFramesChart>
    implements OnChartValueSelectedListener {
  TimelineController _controller;

  List<TimelineFrame> frames = [];

  BarChartController _chartController;

  BarChartController get chartController => _chartController;

  /// Datapoint entry for each frame duration (UI/GPU) for stacked bars.
  final List<BarEntry> _frameDurations = <BarEntry>[];

  /// Set of all duration information (the data, colors, etc).
  BarDataSet frameDurationsSet;

  final int totalFramesToChart = 150;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = Controllers.of(context).timeline;

    // Process each timeline frame.
    _controller.frameBasedTimeline.onFrameAdded.listen((newFrame) {
      setState(() {
        // If frames not in sync with charting data (_frameDurations)?
        if (frames.isEmpty && _frameDurations.length == 1) {
          // Works around a problem with chart appearing before
          // any data so the chart data is primed with a entry.
          _frameDurations.clear(); // Away the fake entry.
        }

        // Prune frames displayed to the last 150 frames.
        if (frames.length > totalFramesToChart) {
          frames.removeAt(0);
          _frameDurations.removeAt(0);
          // TODO(terry): Need a cleaner solution - fixed width bar and
          //              chart that scrolls.
          for (BarEntry entry in _frameDurations) {
            entry.x -= 1; // Fixup all indexes.
          }
        }

        frames.add(newFrame);
        _frameDurations.add(createBarEntry(
          frames.length - 1, // Index into frames.
          newFrame.uiDurationMs,
          newFrame.gpuDurationMs,
        ));

        _updateChart();
      });
    });
  }

  @override
  void dispose() {
    // TODO(kenz): dispose [_controller] here.
    super.dispose();
  }

  @override
  void initState() {
    _initChartController();

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

  void _initChartController() {
    final desc = Description()..enabled = false;
    _chartController = BarChartController(
      axisLeftSettingFunction: (axisLeft, controller) {
        axisLeft
          ..setStartAtZero(true)
          ..typeface = lightTypeFace
          ..drawGridLines = false
          ..setValueFormatter(YAxisUnitFormatter())
          ..addLimitLine(LimitLine(60, '60 FPS')
            // TODO(terry): LEFT_TOP is clipped need to fix in MPFlutterChart.
            ..labelPosition = LimitLabelPosition.RIGHT_TOP
            ..textSize = 10
            ..typeface = boldTypeFace
            // TODO(terry): Below crashed Flutter in Travis see issues/1338.
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

  void frameSelected(int frameIndex) {
    _controller.frameBasedTimeline.selectFrame(frames[frameIndex]);
  }

  /// Light Blue 50 - 200
  static const mainUiColorLight = Color.fromARGB(0xff, 0x81, 0xD4, 0xFA);

  /// Light Blue 50 - 700
  static const mainGpuColorLight = Color.fromARGB(0xFF, 0x02, 0x88, 0xD1);

  void _initData([bool simulateFeed = false]) {
    // Create place holder for empty chart.
    // TODO(terry): Look at fixing MPFlutterChart to handle empty data entries.
    _frameDurations.add(createBarEntry(0, 0, 0));

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
  BarEntry createBarEntry(int index, double uiDuration, double gpuDuration) {
    if (uiDuration + gpuDuration > 250) {
      // Constrain the y-axis so outliers don't blow the barchart scale.
      // TODO(terry): Need to have a max where the hover value shows the real #s but the chart just looks pinned to the top.
      _chartController.axisLeft.setAxisMaximum(250);
    }

    // TODO(terry): Structured class item 0 is GPU, item 1 is UI if not stacked.
    final entry = BarEntry.fromListYVals(
      x: index.toDouble(),
      vals: [
        gpuDuration,
        uiDuration,
      ],
    );

    return entry;
  }

  void _updateChart() {
    _chartController.data = BarData([]..add(frameDurationsSet));

    setState(() {
      // Signal data has changed.
      frameDurationsSet.notifyDataSetChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        height: 200.0,
        child: BarChart(_chartController),
      ),
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
