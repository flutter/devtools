// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mp_chart/mp/chart/bar_chart.dart';
import 'package:mp_chart/mp/controller/bar_chart_controller.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data_set/bar_data_set.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/limit_label_postion.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/limit_line.dart';
import 'package:mp_chart/mp/core/marker/line_chart_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/default_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:provider/provider.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/theme.dart';
import '../../ui/colors.dart';
import '../../ui/theme.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

class FlutterFramesChart extends StatefulWidget {
  const FlutterFramesChart();

  @override
  _FlutterFramesChartState createState() => _FlutterFramesChartState();
}

class _FlutterFramesChartState extends State<FlutterFramesChart>
    with AutoDisposeMixin
    implements OnChartValueSelectedListener {
  static const maxFrames = 150;

  /// Datapoint entry for each frame duration (UI/Raster) for stacked bars.
  final _frameDurations = <BarEntry>[];

  /// Set of all duration information (the data, colors, etc).
  BarDataSet frameDurationsSet;

  BarChartController _chartController;

  BarChartController get chartController => _chartController;

  TimelineController _controller;

  int indexOffset = 0;

  /// Compute the FPS highwater mark based on the displayRefreshRate from
  /// FrameBasedTimeline.
  void _setupFPSHighwaterLine() async {
    if (_chartController.axisLeftSettingFunction == null) {
      final fpsRate = await _controller.displayRefreshRate;

      // Max FPS non-jank value in ms. E.g., 16.6 for 60 FPS, 8.3 for 120 FPS.
      final targetMsPerFrame = 1 / fpsRate * 1000;

      _chartController.axisLeftSettingFunction = (axisLeft, controller) {
        axisLeft
          ..setStartAtZero(true)
          ..typeface = chartLightTypeFace
          ..textColor = defaultForeground
          ..drawGridLines = false
          ..setValueFormatter(YAxisUnitFormatter())
          ..addLimitLine(LimitLine(
            targetMsPerFrame,
            '${fpsRate.toStringAsFixed(0)} FPS',
          )
            // TODO(terry): LEFT_TOP is clipped need to fix in MPFlutterChart.
            ..labelPosition = LimitLabelPosition.RIGHT_TOP
            ..textSize = 10
            ..typeface = chartBoldTypeFace
            // TODO(terry): Below crashed Flutter in Travis see issues/1338.
            // ..enableDashedLine(5, 5, 0)
            ..lineColor = const Color.fromARGB(0x80, 0xff, 0x44, 0x44));
      };
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<TimelineController>(context);
    if (newController == _controller) return;
    _controller = newController;

    cancel();
    autoDispose(_controller.onTimelineCleared.listen((_) {
      setState(() {
        _frameDurations.clear();
        _updateChart();
      });
    }));

    setState(() {
      _setupFPSHighwaterLine();
    });
    autoDispose(_controller.onTimelineProcessed.listen((_) => _loadData()));
    autoDispose(_controller.onLoadOfflineData.listen((_) => _loadData()));
  }

  void _loadData() {
    _frameDurations.clear();
    final frames = _controller.data?.frames ?? [];
    if (frames.isNotEmpty) {
      final startFrameIndex = math.max(0, frames.length - maxFrames);
      for (int i = startFrameIndex; i < frames.length; i++) {
        _frameDurations.add(createBarEntry(frames[i], i - startFrameIndex));
      }
    }
    _updateChart();
  }

  @override
  void initState() {
    _initChartController();
    _initData();
    super.initState();
  }

  void _initChartController() {
    final desc = Description()..enabled = false;
    _chartController = BarChartController(
      backgroundColor: chartBackgroundColor,
      // The axisLeftSettingFunction is computed in didChangeDependencies,
      // see _setupFPSHighwaterLine.
      axisRightSettingFunction: (axisRight, controller) {
        axisRight.enabled = false;
      },
      xAxisSettingFunction: (XAxis xAxis, controller) {
        xAxis
          ..enabled = true
          ..drawLabels = true
          ..setLabelCount1(3)
          ..textColor = defaultForeground
          ..position = XAxisPosition.BOTTOM;
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
      marker: SelectedDataPoint(onSelected: onBarSelected),
      selectionListener: this,
    );

    // Compute padding around chart.
    _chartController.setViewPortOffsets(
        defaultSpacing * 3, denseSpacing, defaultSpacing, defaultSpacing);
  }

  void onBarSelected(int index) {
    _controller.selectFrame(_controller.data.frames[index + indexOffset]);
  }

  void _initData() {
    // Create place holder for empty chart.
    // TODO(terry): Look at fixing MPFlutterChart to handle empty data entries.
    _frameDurations.add(createStubBarEntry());

    // Create heap used dataset.
    frameDurationsSet = BarDataSet(_frameDurations, 'Durations')
      ..setColors1([mainRasterColor, mainUiColor])
      ..setDrawValues(false);

    // Create a data object with all the data sets - stacked bar.
    _chartController.data = BarData([]..add(frameDurationsSet));

    // specify the width each bar should have
    _chartController.data.barWidth = 0.8;
  }

  BarEntry createStubBarEntry() {
    return BarEntry.fromListYVals(x: 0.0, vals: [0.0, 0.0]);
  }

  // TODO(terry): Consider grouped bars (UI/Raster) not stacked.
  BarEntry createBarEntry(TimelineFrame frame, int index) {
    if (frame.uiDurationMs + frame.rasterDurationMs > 250) {
      // Constrain the y-axis so outliers don't blow the barchart scale.
      // TODO(terry): Need to have a max where the hover value shows the real #s but the chart just looks pinned to the top.
      _chartController.axisLeft?.setAxisMaximum(250);
    }

    // TODO(terry): Structured class item 0 is Raster, item 1 is UI if not stacked.
    final entry = BarEntry.fromListYVals(
      x: index.toDouble(),
      vals: [
        frame.rasterDurationMs.toDouble(),
        frame.uiDurationMs.toDouble(),
      ],
    );

    return entry;
  }

  void _updateChart() {
    _chartController.data = BarData([]..add(frameDurationsSet));

    setState(() {
      // Signal data has changed.
      frameDurationsSet.notifyDataSetChanged();
      _setupFPSHighwaterLine();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: liveChartHeight,
          child: BarChart(_chartController),
        ),
        const SizedBox(height: denseSpacing),
      ],
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
      'Raster = ${yValues[0]}, UI = ${yValues[1]}',
    );
  }
}

class YAxisUnitFormatter extends ValueFormatter {
  @override
  String getFormattedValue1(double value) => '${value.toInt()} ms';
}

typedef SelectionCallback = void Function(int frameIndex);

/// Selection of a point in the Bar chart displays the data point values
/// UI duration and Raster duration. Also, highlight the selected stacked bar.
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

    final yValues = (_entry as BarEntry).yVals;

    final num uiDuration = yValues[1];
    final num rasterDuration = yValues[0];

    final TextPainter painter = PainterUtils.create(
      null,
      'UI  = ${_formatter.getFormattedValue1(uiDuration)}\n'
      'Raster = ${_formatter.getFormattedValue1(rasterDuration)}',
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
  }

  @override
  void refreshContent(Entry e, Highlight highlight) async {
    _entry = e;
    // TODO(kenz): see if we can make `x` an int - double seems strange.
    final frameIndex = _entry.x.toInt();
    if (onSelected != null && _lastFrameIndex != frameIndex) {
      _lastFrameIndex = frameIndex;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onSelected(frameIndex));
    }
  }
}
