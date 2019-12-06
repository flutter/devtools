// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'package:mp_chart/mp/chart/line_chart.dart';
import 'package:mp_chart/mp/controller/line_chart_controller.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data/line_data.dart';
import 'package:mp_chart/mp/core/data_set/line_data_set.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
// TODO(terry): Enable legend when textsize is correct.
// import 'package:mp_chart/mp/core/enums/legend_vertical_alignment.dart';
// import 'package:mp_chart/mp/core/enums/legend_form.dart';
// import 'package:mp_chart/mp/core/enums/legend_horizontal_alignment.dart';
// import 'package:mp_chart/mp/core/enums/legend_orientation.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/enums/y_axis_label_position.dart';
import 'package:mp_chart/mp/core/image_loader.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/large_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/controllers.dart';
import '../../flutter/theme.dart';
import '../../ui/theme.dart';
import '../memory_controller.dart';
import '../memory_protocol.dart';

class MemoryChart extends StatefulWidget {
  @override
  MemoryChartState createState() => MemoryChartState();
}

class MemoryChartState extends State<MemoryChart> with AutoDisposeMixin {
  LineChartController _chartController;

  LineChartController get chartController => _chartController;

  MemoryController get _controller => Controllers.of(context).memory;

  MemoryTimeline get _memoryTimeline => _controller.memoryTimeline;

  final legendTypeFace =
      TypeFace(fontFamily: 'OpenSans', fontWeight: FontWeight.w100);

  @override
  void initState() {
    _initController();

    _preloadResources();

    _setupChart();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    cancel();

    // Process each timeline frame.
    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      processLiveData();
    });
  }

  dart_ui.Image _img;

  void _preloadResources() async {
    _img ??= await ImageLoader.loadImage('assets/img/star.png');
  }

  @override
  Widget build(BuildContext context) {
    if (_memoryTimeline.data.isNotEmpty) {
      return Stack(
        children: [LineChart(_chartController)],
      );
    }

    return Stack(
      children: const [Text('No data')],
    );
  }

  void _initController() {
    final desc = Description()..enabled = false;

    _chartController = LineChartController(
        axisLeftSettingFunction: (axisLeft, controller) {
          axisLeft
            ..position = YAxisLabelPosition.OUTSIDE_CHART
            ..setValueFormatter(LargeValueFormatter())
            ..drawGridLines = (true)
            ..granularityEnabled = (true)
            ..setStartAtZero(
                true) // Set to baseline min and auto track max axis range.
            ..textColor = defaultForeground;
        },
        axisRightSettingFunction: (axisRight, controller) {
          axisRight.enabled = false;
        },
        xAxisSettingFunction: (xAxis, controller) {
          xAxis
            ..position = XAxisPosition.BOTTOM
            ..textSize = 10
            ..drawAxisLine = false
            ..drawGridLines = true
            ..textColor = defaultForeground
            ..centerAxisLabels = true
            ..setGranularity(1)
            ..setValueFormatter(XAxisFormatter());
        },
        legendSettingFunction: (legend, controller) {
          legend.enabled = false;
          // TODO(terry): Need to support legend with a smaller text size.
          // legend
          //   ..shape = LegendForm.LINE
          //   ..verticalAlignment = LegendVerticalAlignment.TOP
          //   ..enabled = true
          //   ..orientation = LegendOrientation.HORIZONTAL
          //   ..typeface = legendTypeFace
          //   ..xOffset = 20
          //   ..drawInside = false
          //   ..horizontalAlignment = LegendHorizontalAlignment.CENTER
          //   ..textSize = 6.0;
        },
        highLightPerTapEnabled: true,
        backgroundColor: chartBackgroundColor,
        drawGridBackground: false,
        dragXEnabled: true,
        dragYEnabled: true,
        scaleXEnabled: true,
        scaleYEnabled: true,
        pinchZoomEnabled: false,
        description: desc);

    // Compute padding around chart.
    _chartController.setViewPortOffsets(50, 10, 10, 30);
  }

  @override
  void dispose() {
    super.dispose();
  }

  // TODO(terry): Move _used, _capacity and _externalHeap Controller.
  // TODO(terry): More efficient when switching views.

  /// Datapoint entry for each used heap value.
  final List<Entry> _used = <Entry>[];

  /// Datapoint entry for each capacity heap value.
  final List<Entry> _capacity = <Entry>[];

  /// Datapoint entry for each external memory value.
  final List<Entry> _externalHeap = <Entry>[];

  // Trace #1 Heap Used.
  LineDataSet usedHeapSet;

  // Trace #2 Heap Capacity.
  LineDataSet capacityHeapSet;

  // Trace #3 External Memory used.
  LineDataSet externalMemorySet;

  void processLiveData() {
    final List<HeapSample> liveFeed = _memoryTimeline.data;
    if (_used.length != liveFeed.length) {
      for (var feedIndex = _used.length;
          feedIndex < liveFeed.length;
          feedIndex++) {
        final sample = liveFeed[feedIndex];
        final timestamp = sample.timestamp.toDouble();

        final capacity = sample.capacity.toDouble();
        final used = sample.used.toDouble();
        final external = sample.external.toDouble();

        final extEntry = Entry(
          x: timestamp,
          y: external,
          icon: _img,
        );
        final usedEntry = Entry(
          x: timestamp,
          y: used + external,
          icon: _img,
        );
        final capacityEntry = Entry(
          x: timestamp,
          y: capacity,
          icon: _img,
        );

        setState(() {
          _externalHeap.add(extEntry);
          _used.add(usedEntry);
          _capacity.add(capacityEntry);
        });
      }

      updateChart();
    }
  }

  void updateChart() {
    setState(() {
      // Signal data has changed.
      usedHeapSet.notifyDataSetChanged();
      capacityHeapSet.notifyDataSetChanged();
      externalMemorySet.notifyDataSetChanged();

      _chartController.data = LineData.fromList(
          []..add(usedHeapSet)..add(externalMemorySet)..add(capacityHeapSet));
    });
  }

  void _setupChart() {
    // Create heap used dataset.
    usedHeapSet = LineDataSet(_used, 'Used');
    usedHeapSet
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(ColorUtils.getHoloBlue())
      ..setValueTextColor(ColorUtils.getHoloBlue())
      ..setLineWidth(.7)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setFillAlpha(65)
      ..setFillColor(ColorUtils.getHoloBlue())
      ..setDrawCircleHole(false)
      // Fill in area under set.
      ..setDrawFilled(true)
      ..setFillColor(ColorUtils.getHoloBlue())
      ..setFillAlpha(80);

    // Create heap capacity dataset.
    capacityHeapSet = LineDataSet(_capacity, 'Capacity')
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(ColorUtils.GRAY)
      ..setValueTextColor(ColorUtils.GRAY)
      ..setLineWidth(.5)
      ..enableDashedLine(5, 5, 0)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setFillAlpha(65)
      ..setFillColor(ColorUtils.GRAY)
      ..setDrawCircleHole(false);

    // Create external memory dataset.
    const externalColorLine =
        Color.fromARGB(0xff, 0x42, 0xa5, 0xf5); // Color.blue[400]
    const externalColor =
        Color.fromARGB(0xff, 0x90, 0xca, 0xf9); // Color.blue[200]
    externalMemorySet = LineDataSet(_externalHeap, 'External');
    externalMemorySet
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(externalColorLine)
      ..setLineWidth(.7)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setHighLightColor(const Color.fromARGB(255, 244, 117, 117))
      ..setDrawCircleHole(false)
      // Fill in area under set.
      ..setDrawFilled(true)
      ..setFillColor(externalColor)
      ..setFillAlpha(190);

    // Create a data object with all the data sets.
    _chartController.data = LineData.fromList(
        []..add(usedHeapSet)..add(externalMemorySet)..add(capacityHeapSet));

    _chartController.data
      ..setValueTextColor(ColorUtils.getHoloBlue())
      ..setValueTextSize(9);
  }
}

class XAxisFormatter extends ValueFormatter {
  final intl.DateFormat mFormat = intl.DateFormat('hh:mm:ss.mmm');

  @override
  String getFormattedValue1(double value) {
    return mFormat.format(DateTime.fromMillisecondsSinceEpoch(value.toInt()));
  }
}
