// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'package:mp_chart/mp/chart/line_chart.dart';
import 'package:mp_chart/mp/controller/line_chart_controller.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
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
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/image_loader.dart';
import 'package:mp_chart/mp/core/marker/line_chart_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/large_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/controllers.dart';
import '../../flutter/theme.dart';
import '../../ui/flutter/label.dart';
import '../../ui/theme.dart';
import 'memory_controller.dart';
import 'memory_protocol.dart';

class MemoryChart extends StatefulWidget {
  @override
  MemoryChartState createState() => MemoryChartState();
}

class MemoryChartState extends State<MemoryChart> with AutoDisposeMixin {
  @visibleForTesting
  static const androidChartButtonKey = Key('Android Chart');

  LineChartController chartController;

  MemoryController controller;

  MemoryTimeline get memoryTimeline => controller.memoryTimeline;

  final legendTypeFace =
      TypeFace(fontFamily: 'OpenSans', fontWeight: FontWeight.w100);

  @override
  void initState() {
    _initChartController();

    // Setup for Flutter Engine chart (Android ADB dumpsys meminfo).
    _setupEngineChartController();

    _preloadResources();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    controller = Controllers.of(context).memory;

    _setupChart();
    _setupEngineChartData();

    cancel();

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.memorySourceNotifier, () {
      setState(() {
        controller.updatedMemorySource();

        // Reset all plotted data sets (Entries).
        controller.memoryTimeline.chartData.reset();
        controller.memoryTimeline.engineChartData.reset();

        if (controller.offline) {
          _recomputeOfflineData();
          controller.memoryTimeline.chartData.reset();
          controller.memoryTimeline.engineChartData.reset();
          _processAndUpdate();
        } else {
          // Recompute data to display.
          _recomputeChartData();

          // Plot all offline or online data (based on memorySource).  If
          // not offline then all new heap samples will be plotted as it
          // appears via the sampleAddedNotifier and update all charts.
          _processAndUpdate();
        }
      });
    });

    // Display charts of the data collected in the last n Minutes or all.
    addAutoDisposeListener(controller.displayIntervalNotifier, () {
      // Reset all plotted data sets (Entries).
      controller.memoryTimeline.chartData.reset();
      controller.memoryTimeline.engineChartData.reset();

      if (controller.offline) {
        _recomputeOfflineData();
        controller.memoryTimeline.chartData.reset();
        controller.memoryTimeline.engineChartData.reset();
        _processAndUpdate();
      } else {
        // Recompute data to display.
        _recomputeChartData();

        // Process and plot data in this new display interval.
        _processAndUpdate();
      }
    });

    // Plot each heap sample as it is received.
    addAutoDisposeListener(
      memoryTimeline.sampleAddedNotifier,
      () {
        // Process incoming Samples and update the charts.
        _processAndUpdate();
      },
    );
  }

  dart_ui.Image _img;

  void _preloadResources() async {
    _img ??= await ImageLoader.loadImage('assets/img/star.png');
  }

  Slider timelineSlider;

  double sliderValue = 1.0;

  // Number of interval chunks e.g., 5 minute interval has 3 chunks for 15 minutes of collected data
  int numberOfChunks = 0;

  /// Compute lables for slider.
  String timelineSliderLabel(double value) {
    if (value == 0)
      return 'Starting Time';
    else if (value == numberOfChunks) return 'Ending Time';

    var unitsAgo = numberOfChunks - value;

    switch (controller.pruneInterval) {
      case MemoryController.displayOneMinute:
        unitsAgo = unitsAgo;
        break;
      case MemoryController.displayFiveMinutes:
        unitsAgo = unitsAgo * 5;
        break;
      case MemoryController.displayTenMinutes:
        unitsAgo = unitsAgo * 10;
        break;
    }

    return '$unitsAgo Minute${unitsAgo != 1 ? 's' : ''} Ago';
  }

  @override
  Widget build(BuildContext context) {
    controller.memoryTimeline.image = _img;

    final androidMemoryButton = MaterialIconLabel(
      controller.isAndroidChartVisible ? Icons.close : Icons.show_chart,
      'Android Memory',
      minIncludeTextWidth: 900,
    );

    int chunks = 0;

    if (controller.memoryTimeline.data.isNotEmpty) {
      final lastSampleTimestamp =
          controller.memoryTimeline.data.last.timestamp.toDouble();
      final firstSampleTimestamp =
          controller.memoryTimeline.data.first.timestamp.toDouble();
      chunks = ((lastSampleTimestamp - firstSampleTimestamp) /
              controller.pruneIntervalDurationInMs)
          .round();
    }

    if (chunks != numberOfChunks) {
      // TODO(terry): Need to stay on the same chunk as more chunks arrive.
      // We have more reset to last.
      numberOfChunks = chunks;
      sliderValue = chunks.toDouble();
    }

    timelineSlider = Slider.adaptive(
      label: timelineSliderLabel(sliderValue),
      activeColor: Colors.indigoAccent,
      min: 0.0,
      max: numberOfChunks == 0 ? 1.0 : numberOfChunks.toDouble(),
      inactiveColor: Colors.grey,
      onChanged: numberOfChunks > 0
          ? (newValue) {
              final newChunk = newValue.roundToDouble();
              setState(() {
                sliderValue = newChunk;
                // TODO(terry): Compute:
                // startingIndex = sliderValue * controller.pruneIntervalDurationInMs
              });
            }
          : null,
      value: sliderValue,
      divisions: numberOfChunks == 0 ? 1 : numberOfChunks,
      semanticFormatterCallback: (double newValue) {
        return 'Slot $newValue';
        return '${newValue.round()} dollars';
      },
    );

    if (memoryTimeline.liveData.isNotEmpty) {
      return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 0, 5),
              child: Text('Flutter Framework Heap'),
            ),
            Expanded(
              child: LineChart(chartController),
              flex: 1,
            ),
            Row(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 0, 5),
                child: OutlineButton(
                  key: MemoryChartState.androidChartButtonKey,
                  onPressed: _toggleAndroidChart,
                  child: androidMemoryButton,
                ),
              ),
              Expanded(
                child: timelineSlider,
                flex: 1,
              ),
              const Text('Time Range')
            ]),
            controller.isAndroidChartVisible
                ? Expanded(
                    child: LineChart(engineChartController),
                    flex: 1,
                  )
                : const Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 0, 5),
                    child: Text(''),
                  ),
          ]);
    }

    return const Center(
      child: Text('No data'),
    );
  }

  void _toggleAndroidChart() {
    // TODO(terry): Implement real pause when connected to live feed.
    controller.toggleAndroidChart();
    setState(() {});
  }

  void _initChartController() {
    final desc = Description()..enabled = false;
    final selectedMarker = SelectedDataPoint(
      ChartType.DartHeaps,
      onSelected: onPointSelected,
      getAllValues: getValues,
    );

    chartController = LineChartController(
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
/*
        legend
          ..shape = LegendForm.LINE
          ..verticalAlignment = LegendVerticalAlignment.TOP
          ..enabled = true
          ..orientation = LegendOrientation.HORIZONTAL
          ..typeface = legendTypeFace
          ..xOffset = 20
          ..drawInside = false
          ..horizontalAlignment = LegendHorizontalAlignment.CENTER
          ..textSize = 2.0;
*/
      },
      highLightPerTapEnabled: true,
      backgroundColor: chartBackgroundColor,
      doubleTapToZoomEnabled: false,
      drawGridBackground: false,
      dragXEnabled: true,
      dragYEnabled: true,
      // TODO(terry): For now disable zoom with double-click.
      scaleXEnabled: true,
      scaleYEnabled: true,
      pinchZoomEnabled: false,
      description: desc,
      marker: selectedMarker,
      selectionListener: MySelectionListener(selectedMarker),
    );

    // Compute padding around chart.
    chartController.setViewPortOffsets(50, 20, 10, 0);
  }

  /// Plots the Android ADB memory info (Flutter Engine).
  LineChartController engineChartController;

  void _setupEngineChartController() {
    final desc = Description()..enabled = false;
    final selectedMarker = SelectedDataPoint(
      ChartType.AndroidHeaps,
      onSelected: onPointSelected,
      getAllValues: getValues,
    );
    engineChartController = LineChartController(
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
/*
        legend
          ..shape = LegendForm.LINE
          ..verticalAlignment = LegendVerticalAlignment.TOP
          ..enabled = true
          ..orientation = LegendOrientation.HORIZONTAL
          ..typeface = legendTypeFace
          ..xOffset = 20
          ..drawInside = false
          ..horizontalAlignment = LegendHorizontalAlignment.CENTER
          ..textSize = 2.0;
*/
      },
      highLightPerTapEnabled: true,
      backgroundColor: chartBackgroundColor,
      drawGridBackground: false,
      dragXEnabled: true,
      dragYEnabled: true,
      // TOD(terry): For now disable zoom via double-click. Consider +/- button
      //             for a controlled zoom in/zoom out.
      scaleXEnabled: false,
      scaleYEnabled: false,
      pinchZoomEnabled: false,
      description: desc,
      marker: selectedMarker,
      selectionListener: MySelectionListener(selectedMarker),
    );

    // Compute padding around chart.
    engineChartController.setViewPortOffsets(50, 0, 10, 30);
  }

  void _setupTrace(LineDataSet traceSet, Color color, int alpha) {
    traceSet
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(color)
      ..setValueTextColor(color)
      ..setLineWidth(.7)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setDrawCircleHole(false)
      // Fill in area under set.
      ..setDrawFilled(true)
      ..setFillColor(color)
      ..setFillAlpha(alpha);
  }

  void _setupEngineChartData() {
    final engineChartData = memoryTimeline.engineChartData;

    stackSizeSet = LineDataSet(engineChartData.stack, 'Stack');
    _setupTrace(stackSizeSet, ColorUtils.WHITE, 220);

    graphicsSizeSet = LineDataSet(engineChartData.graphics, 'Graphics');
    _setupTrace(graphicsSizeSet, ColorUtils.HOLO_ORANGE_DARK, 180);

    // Create Native Heap dataset.
    nativeHeapSet = LineDataSet(engineChartData.nativeHeap, 'Native Heap');
    _setupTrace(nativeHeapSet, ColorUtils.HOLO_BLUE_LIGHT, 140);
    nativeHeapSet.setDrawIcons(true);

    javaHeapSet = LineDataSet(engineChartData.javaHeap, 'Java Heap');
    _setupTrace(javaHeapSet, ColorUtils.YELLOW, 100);

    codeSizeSet = LineDataSet(engineChartData.code, 'Code');
    _setupTrace(codeSizeSet, ColorUtils.GRAY, 80);

    otherSizeSet = LineDataSet(engineChartData.other, 'Other');
    _setupTrace(otherSizeSet, ColorUtils.HOLO_PURPLE, 40);

    /// TODO(terry): The last trace combine system and other.
    systemSizeSet = LineDataSet(engineChartData.system, 'System');
    _setupTrace(systemSizeSet, ColorUtils.HOLO_GREEN_DARK, 0);

    totalSizeSet = LineDataSet(engineChartData.total, 'Total')
      ..setAxisDependency(AxisDependency.LEFT)
      ..setColor1(ColorUtils.LTGRAY)
      ..setValueTextColor(ColorUtils.LTGRAY)
      ..setLineWidth(.5)
      ..enableDashedLine(5, 5, 0)
      ..setDrawCircles(false)
      ..setDrawValues(false)
      ..setFillAlpha(255)
      ..setFillColor(ColorUtils.LTGRAY)
      ..setDrawCircleHole(false);

    // Create a data object with all the data sets.
    chartController.data = LineData.fromList(
      []
        ..add(javaHeapSet)
        ..add(nativeHeapSet)
        ..add(codeSizeSet)
        ..add(stackSizeSet)
        ..add(graphicsSizeSet)
        ..add(otherSizeSet)
        ..add(systemSizeSet)
        ..add(totalSizeSet),
    );

    chartController.data
      ..setValueTextColor(ColorUtils.getHoloBlue())
      ..setValueTextSize(9);
  }

  // Trace #1 Java Heap.
  LineDataSet javaHeapSet;

  // Trace #2 Native Heap.
  LineDataSet nativeHeapSet;

  // Trace #3 Code Size.
  LineDataSet codeSizeSet;

  // Trace #4 Stack Size.
  LineDataSet stackSizeSet;

  // Trace #5 Graphics Size.
  LineDataSet graphicsSizeSet;

  // Trace #6 Other Size.
  LineDataSet otherSizeSet;

  // Trace #7 System Size.
  LineDataSet systemSizeSet;

  // Trace #8 Total Size.
  LineDataSet totalSizeSet;

  /// When point selected e.g., LineChartMarker find the HeapSample.
  void onPointSelected(int xValueTimestamp) {
    if (controller.selectedSample?.timestamp != xValueTimestamp) {
      controller.selectedSample = null;

      final data = controller.memoryTimeline.data;
      for (var index = 0; index < data.length; index++) {
        if (data[index].timestamp == xValueTimestamp) {
          controller.selectedSample = data[index];
        }
      }
    }
  }

  HeapSample getValues(int timestamp) {
    final data = controller.memoryTimeline.data;
    final start = controller.memoryTimeline.startingIndex;

    // Is the marker being displayed in the visible range?
    if (timestamp > data[start].timestamp) {
      if (controller.selectedSample?.timestamp == timestamp)
        return controller.selectedSample;

      controller.selectedSample = null;

      for (var index = 0; index < data.length; index++) {
        if (data[index].timestamp == timestamp) {
          controller.selectedSample = data[index];
          break;
        }
      }
    } else {
      // Marker no longer in visible range.
      controller.selectedSample = null;
      // TODO(terry): BUG in MP chart / Dart bug unable to unselect the highlighted values.
      // Failure in method drawMarkers in lib/mp/painter/painter.dart @ the line
      //
      //      for (int i = 0; i < _indicesToHighlight.length; i++) {
      //
      // This line shouldn't execute  _indicesToHighlight is null, first line in drawMarkers
      // below should cause return
      //
      //   if (_marker == null || !_drawMarkers || !valuesToHighlight()) return;
      //
      // For some reason valuesToHightlight() isn't false, however, valuesToHighlight
      // seems correct.
      //
      // Below line should be:
      //    chartController.painter.highlightValues(null);
      chartController.painter.highlightValues([]);
    }

    return controller.selectedSample;
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Trace #1 Heap Used.
  LineDataSet usedHeapSet;

  // Trace #2 Heap Capacity.
  LineDataSet capacityHeapSet;

  // Trace #3 External Memory used.
  LineDataSet externalMemorySet;

  /// Loads all heap samples (live data or offline).
  void _processAndUpdate([bool reloadAllData = false]) {
    setState(() {
      if (reloadAllData) {
        controller.recomputeData();
      }

      controller.processData(reloadAllData);

      // Display all charts with the new data.
      _updateCharts();
    });
  }

  void _recomputeOfflineData() {
    setState(() {
      controller.recomputeOfflineData();

      // Display all charts with the new data.
      _updateCharts();
    });
  }

  /// Recompute the startingIndex and endingIndex from all HeapSample to
  /// the chart's LineDataSet (entries) based on the curent display interval.
  void _recomputeChartData() {
    setState(() {
      controller.recomputeData();
    });
  }

  /// Display any newly received heap sample(s) in the chart.
  void _updateCharts() {
    setState(() {
      // Update Dart VM chart datasets.
      chartController.data = LineData.fromList(
          []..add(usedHeapSet)..add(externalMemorySet)..add(capacityHeapSet));

      // Received new samples ready to plot, signal data has changed.
      usedHeapSet.notifyDataSetChanged();
      capacityHeapSet.notifyDataSetChanged();
      externalMemorySet.notifyDataSetChanged();

      // Update Android Memory chart datasets.
      engineChartController.data = LineData.fromList([]
        ..add(javaHeapSet)
        ..add(nativeHeapSet)
        ..add(codeSizeSet)
        ..add(stackSizeSet)
        ..add(graphicsSizeSet)
        ..add(otherSizeSet)
        ..add(systemSizeSet)
        ..add(totalSizeSet));

      // Received ADB memory info from samples ready to plot, signal data has changed.
      javaHeapSet.notifyDataSetChanged();
      nativeHeapSet.notifyDataSetChanged();
      codeSizeSet.notifyDataSetChanged();
      stackSizeSet.notifyDataSetChanged();
      graphicsSizeSet.notifyDataSetChanged();
      otherSizeSet.notifyDataSetChanged();
      systemSizeSet.notifyDataSetChanged();
      totalSizeSet.notifyDataSetChanged();
    });
  }

  void _setupChart() {
    final chartData = memoryTimeline.chartData;

    // Create heap used dataset.
    usedHeapSet = LineDataSet(chartData.used, 'Used');
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
    capacityHeapSet = LineDataSet(chartData.capacity, 'Capacity')
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
    externalMemorySet = LineDataSet(chartData.externalHeap, 'External');
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
    chartController.data = LineData.fromList(
      []
        ..add(
          usedHeapSet,
        )
        ..add(
          externalMemorySet,
        )
        ..add(
          capacityHeapSet,
        ),
    );

    chartController.data
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

typedef SelectionCallback = void Function(int timestamp);

typedef AllValuesCallback = HeapSample Function(int timestamp);

enum ChartType { DartHeaps, AndroidHeaps }

/// Selection of a point in the Bar chart displays the data point values
/// UI duration and GPU duration. Also, highlight the selected stacked bar.
/// Uses marker/highlight mechanism which lags because it uses onTapUp maybe
/// onTapDown would be less laggy.
///
/// onSelected callback function invoked when bar entry is selected.
class SelectedDataPoint extends LineChartMarker {
  SelectedDataPoint(
    this.type, {
    this.textColor,
    this.backColor,
    this.fontSize,
    this.onSelected,
    this.getAllValues,
  }) {
    _timestampFormatter = XAxisFormatter();
    _formatter = LargeValueFormatter();
    textColor ??= ColorUtils.WHITE;
    backColor ??= const Color.fromARGB(127, 0, 0, 0);
    fontSize ??= 10;
  }

  ChartType type;

  Entry _entry;

  set entry(Entry e) {
    _entry = e;
  }

  LargeValueFormatter _formatter;

  XAxisFormatter _timestampFormatter;

  Color textColor;

  Color backColor;

  double fontSize;

  final SelectionCallback onSelected;

  final AllValuesCallback getAllValues;

  @override
  void draw(Canvas canvas, double posX, double posY) {
    const positionAboveBar = 15;
    const xPaddingAroundText = 15;
    const yPaddingAroundText = xPaddingAroundText ~/ 4;
    const rectangleCurve = 5.0;

    /// Text X starting position for Dart VM values.
    const dartValuesXOffset = 48.0;

    /// Text X starting position for Android values.
    const androidValuesXOffset = 65.0;

    if (_entry == null) return;

    final timestampAsInt = _entry.x.toInt();

    final values = getAllValues(timestampAsInt);

    // No values selected or values are out of range, so no marker to display.
    if (values == null) return;

    assert(values.timestamp == timestampAsInt);

    final num heapCapacity = values.capacity.toDouble();
    final num heapUsed = values.used.toDouble();
    final num external = values.external.toDouble();
    final num rss = values.rss.toDouble();
    final bool isGced = values.isGC;

    // Alpha filled stacked:
    final num memoryOther = values.memoryInfo.other.toDouble(); // Purple-ish
    final num memoryCode = values.memoryInfo.code.toDouble(); // Gray Purple
    final num memoryNativeHeap =
        values.memoryInfo.nativeHeap.toDouble(); // Blue-ish
    final num memoryJavaHeap =
        values.memoryInfo.javaHeap.toDouble(); // Green-ish
    final num memoryStack = values.memoryInfo.stack.toDouble(); // White-ish
    final num memoryGraphics = values.memoryInfo.graphics.toDouble(); // Orangy

    final num memoryTotal = values.memoryInfo.total.toDouble(); // dashed line

    final num memorySystem =
        values.memoryInfo.system.toDouble(); // Should report as system+other

    final TextPainter painter = type == ChartType.DartHeaps
        ? PainterUtils.create(null, _titlesDartVm, textColor, fontSize)
        : PainterUtils.create(null, _titlesAndroid, textColor, fontSize);

    painter.textAlign = TextAlign.left;

    // Compute the values of each point for a particular x position (timestamp).
    final TextPainter painterValues = type == ChartType.DartHeaps
        ? PainterUtils.create(
            null,
            '${_timestampFormatter.getFormattedValue1(timestampAsInt.toDouble())}\n'
            '${_formatter.getFormattedValue1(heapCapacity)}\n'
            '${_formatter.getFormattedValue1(heapUsed)}\n'
            '${_formatter.getFormattedValue1(external)}\n'
            '${_formatter.getFormattedValue1(rss)}\n'
            '$isGced',
            textColor,
            fontSize,
          )
        : PainterUtils.create(
            null,
            '${_timestampFormatter.getFormattedValue1(timestampAsInt.toDouble())}\n'
            '${_formatter.getFormattedValue1(memoryTotal)}\n'
            '${_formatter.getFormattedValue1(memoryOther)}\n'
            '${_formatter.getFormattedValue1(memoryCode)}\n'
            '${_formatter.getFormattedValue1(memoryNativeHeap)}\n'
            '${_formatter.getFormattedValue1(memoryJavaHeap)}\n'
            '${_formatter.getFormattedValue1(memoryStack)}\n'
            '${_formatter.getFormattedValue1(memoryGraphics)}',
            textColor,
            fontSize,
          );
    painterValues.textAlign = TextAlign.right;

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
    painterValues.layout();

    final Offset pos = calculatePos(
      posX + offset.x,
      posY + offset.y - positionAboveBar,
      painter.width + painterValues.width,
      painter.height,
    );

    canvas.drawRRect(
      RRect.fromLTRBR(
        pos.dx - xPaddingAroundText,
        pos.dy - yPaddingAroundText,
        pos.dx + painter.width + painterValues.width + xPaddingAroundText,
        pos.dy + painter.height + yPaddingAroundText,
        const Radius.circular(rectangleCurve),
      ),
      paint,
    );

    _drawColorLegend(
      type == ChartType.DartHeaps ? _dartVMColors : _androidColors,
      canvas,
      paint,
      pos,
    );

    // Paint the static text.
    painter.paint(canvas, pos);

    // Paint the computed text values.
    final valuePos = pos.translate(
      type == ChartType.DartHeaps ? dartValuesXOffset : androidValuesXOffset,
      0,
    );
    painterValues.paint(canvas, valuePos);

    canvas.restore();
  }

  final String _titlesDartVm = 'Time\n'
      'Capacity\n'
      'Used\n'
      'External\n'
      'RSS\n'
      'GC';

  // These are the alpha blended values.
  final List<Color> _dartVMColors = [
    ColorUtils.GRAY, // Total dashed line (Capacity)
    const Color(0xff315a69), // Aqua (Used)
    const Color(0xff77aed5), // Light-Blue (External)
  ];

  final String _titlesAndroid = 'Time\n'
      'Total\n'
      'Other\n'
      'Code\n'
      'Native Heap\n'
      'Java Heap\n'
      'Stack\n'
      'Graphics';

  // These are the alpha blended values.
  final List<Color> _androidColors = [
    ColorUtils.WHITE, // Total dashed line (Total)
    const Color(0xff945caf), // Purple-ish (Other)
    const Color(0xff6a5caf), // Gray Purple-ish (Code)
    const Color(0xff607ebe), // Blue-ish (Native Heap)
    const Color(0xff75b479), // Green-ish (Java Heap)
    const Color(0xffe1dbea), // White-ish (Stack)
    const Color(0xffec935d), // Orangy (Graphics)
  ];

  void _drawColorLegend(
    List<Color> colors,
    Canvas canvas,
    Paint paint,
    Offset pos,
  ) {
    const dashDrawWidth = 4.0;
    const dashSkipWidth = 2.0;

    const swatchHeight = 8.0;
    const swatchWidth = 10.0;
    const swatchXOffset = 12.0;
    const swatchYOffset = 11.0;
    const swatchYHalfOffset = swatchYOffset ~/ 2.0;

    final xOffset = pos.dx - swatchXOffset;
    var yOffset = pos.dy + swatchYOffset + swatchYHalfOffset; // Dashed line

    // Draw the dashed line key.
    paint.color = colors[0];
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    var p1 = Offset(xOffset, yOffset);
    var p2 = p1.translate(dashDrawWidth, 0);
    canvas.drawLine(p1, p2, paint);
    p1 = p2.translate(dashSkipWidth, 0);
    p2 = p1.translate(dashDrawWidth, 0);
    canvas.drawLine(p1, p2, paint);

    // Color swatches start vertically after time and dashed line entries.
    yOffset = swatchYOffset * 2 + 1;

    paint.style = PaintingStyle.fill;
    for (var index = 1; index < colors.length; index++) {
      paint.color = colors[index];
      canvas.drawRect(
        Rect.fromLTWH(xOffset, pos.dy + yOffset, swatchWidth, swatchHeight),
        paint,
      );
      yOffset += swatchYOffset;
    }
  }
}

class MySelectionListener implements OnChartValueSelectedListener {
  MySelectionListener(this.selectedDataPoint);

  SelectedDataPoint selectedDataPoint;

  @override
  void onNothingSelected() {}

  @override
  void onValueSelected(Entry e, Highlight h) {
    selectedDataPoint.entry = e;
  }
}
