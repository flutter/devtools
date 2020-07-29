// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as dart_ui;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
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
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../theme.dart';
import '../ui/theme.dart';
import 'memory_controller.dart';
import 'memory_timeline.dart';

class MemoryChart extends StatefulWidget {
  @override
  MemoryChartState createState() => MemoryChartState();
}

class MemoryChartState extends State<MemoryChart> with AutoDisposeMixin {
  LineChartController dartChartController;

  MemoryController controller;

  MemoryTimeline get memoryTimeline => controller.memoryTimeline;

  final legendTypeFace =
      TypeFace(fontFamily: 'OpenSans', fontWeight: FontWeight.w100);

  @override
  void initState() {
    super.initState();

    _preloadResources();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    controller = Provider.of<MemoryController>(context);

    // TODO(jacobr): this is an ugly way to be using the theme. It would be
    // better if the controllers weren't involved with the color scheme.
    final colorScheme = Theme.of(context).colorScheme;
    _setupDartChartController(colorScheme);

    // Setup for Flutter Engine chart (Android ADB dumpsys meminfo).
    _setupAndroidChartController(colorScheme);

    // Hookup access to the MemoryController when a data point is clicked
    // in a chart.
    _selectedDartChart?.memoryController = controller;
    _selectedAndroidChart?.memoryController = controller;

    _setupDartChartData();
    _setupAndroidChartData();

    cancel();

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.memorySourceNotifier, () {
      setState(() {
        controller.updatedMemorySource();
        _refreshCharts();
      });
    });

    // Display charts of the data collected in the last n Minutes or all.
    addAutoDisposeListener(controller.displayIntervalNotifier, () {
      _refreshCharts();
    });

    addAutoDisposeListener(memoryTimeline.markerHiddenNotifier, () {
      controller.setSelectedSample(ChartType.DartHeaps, null);
      hideMarkers(ChartType.DartHeaps);

      controller.setSelectedSample(ChartType.AndroidHeaps, null);
      hideMarkers(ChartType.AndroidHeaps);
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

  void _refreshCharts() {
    // Reset all plotted data sets (Entries).
    controller.memoryTimeline.dartChartData.reset();
    controller.memoryTimeline.eventsChartData.reset();
    controller.memoryTimeline.androidChartData.reset();

    if (controller.offline) {
      _recomputeOfflineData();
      controller.memoryTimeline.dartChartData.reset();
      controller.memoryTimeline.androidChartData.reset();
    } else {
      // Recompute data to display.
      _recomputeChartData();
    }

    // Plot all offline or online data (based on memorySource).  If
    // not offline then all new heap samples will be plotted as it
    // appears via the sampleAddedNotifier and update all charts.
    _processAndUpdate();
  }

  dart_ui.Image _img;

  void _preloadResources() async {
    _img ??= await ImageLoader.loadImage('assets/img/star.png');
  }

  Slider _timelineSlider;

  SelectedDataPoint _selectedDartChart;
  SelectedDataPoint _selectedAndroidChart;

  /// Compute increments for slider and labels for slider increments based on
  /// the current display interval time period.
  String timelineSliderLabel(double value) {
    if (value == 0)
      return 'Starting Time';
    else if (value == controller.numberOfStops) return 'Ending Time';

    var unitsAgo = controller.numberOfStops - value;

    switch (controller.displayInterval) {
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

  Slider _createTimelineSlider() {
    return Slider.adaptive(
      label: timelineSliderLabel(controller.sliderValue),
      activeColor: Colors.indigoAccent,
      max: controller.numberOfStops.toDouble(),
      inactiveColor: Colors.grey,
      onChanged: controller.numberOfStops > 0
          ? (newValue) {
              final newChunk = newValue.roundToDouble();
              setState(
                () {
                  controller.sliderValue = newChunk;
                  // TODO(terry): Compute:
                  //    startingIndex = sliderValue * controller.intervalDurationInMs
                },
              );
            }
          : null,
      value: controller.sliderValue,
      divisions: controller.numberOfStops,
    );
  }

  @override
  Widget build(BuildContext context) {
    controller.memoryTimeline.image = _img;

    // Compute number of stops for the timeline slider.
    final stops = controller.computeStops();
    if (stops != controller.numberOfStops) {
      // TODO(terry): Need to stay on the same stop as more stops created.
      // Move reset to last?
      controller.sliderValue = stops.toDouble();
    }
    controller.numberOfStops = stops;

    _timelineSlider = _createTimelineSlider();

    return Column(
      children: [
        memoryTimeline.liveData.isEmpty
            ? const SizedBox()
            : SizedBox(
                height: defaultChartHeight,
                child: LineChart(dartChartController),
              ),
        controller.isAndroidChartVisible
            ? SizedBox(
                height: defaultChartHeight,
                child: LineChart(androidChartController),
              )
            : const SizedBox(),
        SizedBox(child: _timelineSlider),
      ],
    );
  }

  void _setupDartChartController(ColorScheme colorScheme) {
    final desc = Description()..enabled = false;
    _selectedDartChart = SelectedDataPoint(
      ChartType.DartHeaps,
      getSelectedSampleValue: getDartSelectedSample,
    );

    dartChartController = LineChartController(
      axisLeftSettingFunction: (axisLeft, controller) {
        axisLeft
          ..position = YAxisLabelPosition.OUTSIDE_CHART
          ..setValueFormatter(LargeValueFormatter())
          ..drawGridLines = true
          ..granularityEnabled = true
          // Set to baseline min and auto track max axis range.
          ..setStartAtZero(true)
          ..textColor = colorScheme.defaultForeground;
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
          ..textColor = colorScheme.defaultForeground
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
      backgroundColor: colorScheme.defaultBackgroundColor,
      doubleTapToZoomEnabled: false,
      // TODO(terry): For now disable zoom with double-click.
      pinchZoomEnabled: false,
      description: desc,
      marker: _selectedDartChart,
      selectionListener: DataPointSelectedistener(_selectedDartChart),
    );

    // Compute padding around chart.
    dartChartController.setViewPortOffsets(
        defaultSpacing * 3, 0, defaultSpacing, defaultSpacing);
  }

  /// Plots the Android ADB memory info (Flutter Engine).
  LineChartController androidChartController;

  void _setupAndroidChartController(ColorScheme colorScheme) {
    final desc = Description()..enabled = false;
    _selectedAndroidChart = SelectedDataPoint(
      ChartType.AndroidHeaps,
      getSelectedSampleValue: getAndroidSelectedSample,
    );
    androidChartController = LineChartController(
      axisLeftSettingFunction: (axisLeft, controller) {
        axisLeft
          ..position = YAxisLabelPosition.OUTSIDE_CHART
          ..setValueFormatter(LargeValueFormatter())
          ..drawGridLines = true
          ..granularityEnabled = true
          // Set to baseline min and auto track max axis range.
          ..setStartAtZero(true)
          ..textColor = colorScheme.defaultForeground;
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
          ..textColor = colorScheme.defaultForeground
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
      backgroundColor: colorScheme.defaultBackgroundColor,
      // TOD(terry): Disable zoom via double-click. Consider +/- button
      //             for a controlled zoom in/zoom out.
      scaleXEnabled: false,
      scaleYEnabled: false,
      pinchZoomEnabled: false,
      description: desc,
      marker: _selectedAndroidChart,
      selectionListener: DataPointSelectedistener(_selectedAndroidChart),
    );

    // Compute padding around chart.
    androidChartController.setViewPortOffsets(
        defaultSpacing * 3, denseSpacing, defaultSpacing, defaultSpacing);
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

  void _setupAndroidChartData() {
    final androidChartData = memoryTimeline.androidChartData;

    stackSizeSet = LineDataSet(androidChartData.stack, 'Stack');
    _setupTrace(stackSizeSet, ColorUtils.WHITE, 220);

    graphicsSizeSet = LineDataSet(androidChartData.graphics, 'Graphics');
    _setupTrace(graphicsSizeSet, ColorUtils.HOLO_ORANGE_DARK, 180);

    // Create Native Heap dataset.
    nativeHeapSet = LineDataSet(androidChartData.nativeHeap, 'Native Heap');
    _setupTrace(nativeHeapSet, ColorUtils.HOLO_BLUE_LIGHT, 140);
    nativeHeapSet.setDrawIcons(true);

    javaHeapSet = LineDataSet(androidChartData.javaHeap, 'Java Heap');
    _setupTrace(javaHeapSet, ColorUtils.YELLOW, 100);

    codeSizeSet = LineDataSet(androidChartData.code, 'Code');
    _setupTrace(codeSizeSet, ColorUtils.GRAY, 80);

    otherSizeSet = LineDataSet(androidChartData.other, 'Other');
    _setupTrace(otherSizeSet, ColorUtils.HOLO_PURPLE, 40);

    /// TODO(terry): The last trace combine system and other.
    systemSizeSet = LineDataSet(androidChartData.system, 'System');
    _setupTrace(systemSizeSet, ColorUtils.HOLO_GREEN_DARK, 0);

    totalSizeSet = LineDataSet(androidChartData.total, 'Total')
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

    // TODO(terry): Dash crashes Canvas unimplemented in Flutter Web see issue
    //              https://github.com/flutter/flutter/issues/49882.
    if (kIsWeb) {
      // Disable dash and set the color to greenish.
      totalSizeSet
        ..disableDashedLine()
        ..setColor1(ColorUtils.HOLO_GREEN_LIGHT);
    }

    // Create a data object with all the data sets.
    androidChartController.data = LineData.fromList(
      [
        javaHeapSet,
        nativeHeapSet,
        codeSizeSet,
        stackSizeSet,
        graphicsSizeSet,
        otherSizeSet,
        systemSizeSet,
        totalSizeSet,
      ],
    );

    androidChartController.data
      ..setValueTextColor(ColorUtils.getHoloBlue())
      ..setValueTextSize(9);
  }

  final adbDatasets = List<LineDataSet>.generate(
    ADBDataSets.values.length,
    (int) => null,
  );

  /// Trace #1 Java Heap.
  LineDataSet get javaHeapSet => adbDatasets[ADBDataSets.javaHeapSet.index];
  set javaHeapSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.javaHeapSet.index] = dataset;
  }

  /// Trace #2 Native Heap.
  LineDataSet get nativeHeapSet => adbDatasets[ADBDataSets.nativeHeapSet.index];
  set nativeHeapSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.nativeHeapSet.index] = dataset;
  }

  /// Trace #3 Code Size.
  LineDataSet get codeSizeSet => adbDatasets[ADBDataSets.codeSet.index];
  set codeSizeSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.codeSet.index] = dataset;
  }

  /// Trace #4 Stack Size.
  LineDataSet get stackSizeSet => adbDatasets[ADBDataSets.stackSet.index];
  set stackSizeSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.stackSet.index] = dataset;
  }

  /// Trace #5 Graphics Size.
  LineDataSet get graphicsSizeSet => adbDatasets[ADBDataSets.graphicsSet.index];
  set graphicsSizeSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.graphicsSet.index] = dataset;
  }

  /// Trace #6 Other Size.
  LineDataSet get otherSizeSet => adbDatasets[ADBDataSets.otherSet.index];
  set otherSizeSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.otherSet.index] = dataset;
  }

  /// Trace #7 System Size.
  LineDataSet get systemSizeSet => adbDatasets[ADBDataSets.systemSet.index];
  set systemSizeSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.systemSet.index] = dataset;
  }

  /// Trace #8 Total Size.
  LineDataSet get totalSizeSet => adbDatasets[ADBDataSets.totalSet.index];
  set totalSizeSet(LineDataSet dataset) {
    adbDatasets[ADBDataSets.totalSet.index] = dataset;
  }

  /// Get the HeapSample that is selected for the Dart chart.
  HeapSample getDartSelectedSample(int timestamp) =>
      _getValues(ChartType.DartHeaps, timestamp);

  /// Get the HeapSample that is selected for the Android chart.
  HeapSample getAndroidSelectedSample(int timestamp) =>
      _getValues(ChartType.AndroidHeaps, timestamp);

  HeapSample _getValues(ChartType type, int timestamp) {
    final start = controller.memoryTimeline.startingIndex;

    // Is this sample still in the visible range?
    if (timestamp < controller.memoryTimeline.data[start].timestamp) {
      // No, remove the selection.
      controller.setSelectedSample(type, null);
    }

    if (controller.getSelectedSample(type) == null) {
      hideMarkers(type);
    }

    final currentSelection = controller.getSelectedSample(type);
    assert(currentSelection != null
        ? currentSelection.timestamp == timestamp
        : true);
    return currentSelection;
  }

  void hideMarkers(ChartType type) {
    switch (type) {
      case ChartType.DartHeaps:
        dartChartController.painter?.highlightValues([null]);
        break;
      case ChartType.AndroidHeaps:
        androidChartController?.painter?.highlightValues([null]);
        break;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  final chartDatasets = List<LineDataSet>.generate(
    ChartDataSets.values.length,
    (int) => null,
  );

  // Trace #1 Heap Used.
  LineDataSet get usedHeapSet => chartDatasets[ChartDataSets.usedSet.index];
  set usedHeapSet(LineDataSet dataset) {
    chartDatasets[ChartDataSets.usedSet.index] = dataset;
  }

  // Trace #2 Heap Capacity.
  LineDataSet get capacityHeapSet =>
      chartDatasets[ChartDataSets.capacitySet.index];
  set capacityHeapSet(LineDataSet dataset) {
    chartDatasets[ChartDataSets.capacitySet.index] = dataset;
  }

  // Trace #3 External Memory used.
  LineDataSet get externalMemorySet =>
      chartDatasets[ChartDataSets.externalHeapSet.index];
  set externalMemorySet(LineDataSet dataset) {
    chartDatasets[ChartDataSets.externalHeapSet.index] = dataset;
  }

  /// Loads all heap samples (live data or offline).
  void _processAndUpdate([bool reloadAllData = false]) {
    setState(() {
      if (reloadAllData) {
        controller.recomputeData();
      }

      controller.processData(reloadAllData);

      // Display all charts with the new data.
      _updateAllCharts();
    });
  }

  void _recomputeOfflineData() {
    setState(() {
      controller.recomputeOfflineData();

      // Display all charts with the new data.
      _updateAllCharts();
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
  void _updateAllCharts() {
    setState(() {
      // Update Dart VM chart datasets.
      dartChartController.data = LineData.fromList(chartDatasets);

      // Received new samples ready to plot, signal data has changed.
      for (final dataSet in chartDatasets) {
        dataSet.notifyDataSetChanged();
      }

      // Update Android Memory chart datasets.
      androidChartController.data = LineData.fromList(adbDatasets);

      // Received ADB memory info from samples ready to plot, signal data has changed.
      for (final dataSet in adbDatasets) {
        dataSet.notifyDataSetChanged();
      }
    });
  }

  void _setupDartChartData() {
    final dartChartData = memoryTimeline.dartChartData;

    // Create heap used dataset.
    usedHeapSet = LineDataSet(dartChartData.used, 'Used');
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
    capacityHeapSet = LineDataSet(dartChartData.capacity, 'Capacity')
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

    // TODO(terry): Dash crashes Canvas unimplemented in Flutter Web see issue
    //              https://github.com/flutter/flutter/issues/49882.
    if (kIsWeb) {
      // Disable dash and set the color to greenish.
      capacityHeapSet
        ..disableDashedLine()
        ..setColor1(ColorUtils.HOLO_GREEN_LIGHT);
    }

    // Create external memory dataset.
    const externalColorLine =
        Color.fromARGB(0xff, 0x42, 0xa5, 0xf5); // Color.blue[400]
    const externalColor =
        Color.fromARGB(0xff, 0x90, 0xca, 0xf9); // Color.blue[200]
    externalMemorySet = LineDataSet(dartChartData.externalHeap, 'External');
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
    dartChartController.data = LineData.fromList(
      [
        usedHeapSet,
        externalMemorySet,
        capacityHeapSet,
      ],
    );

    dartChartController.data
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

typedef SelectSampleCallback = HeapSample Function(int timestamp);

class SelectedDataPoint extends LineChartMarker {
  SelectedDataPoint(
    this.type, {
    this.textColor,
    this.backColor,
    this.fontSize,
    this.getSelectedSampleValue,
  }) {
    _timestampFormatter = XAxisFormatter();
    _formatter = LargeValueFormatter();
    textColor ??= ColorUtils.WHITE;
    backColor ??= const Color.fromARGB(127, 0, 0, 0);
    fontSize ??= 10;
  }

  ChartType type;

  MemoryController memoryController;

  Entry _entry;

  set entry(Entry e) {
    _entry = e;
  }

  LargeValueFormatter _formatter;

  XAxisFormatter _timestampFormatter;

  Color textColor;

  Color backColor;

  double fontSize;

  final SelectSampleCallback getSelectedSampleValue;

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

    final values = getSelectedSampleValue(timestampAsInt);

    // No values selected or values are out of range, so no marker to display.
    if (values == null) return;

    assert(values.timestamp == timestampAsInt);

    final num heapCapacity = values.capacity.toDouble();
    final num heapUsed = values.used.toDouble();
    final num external = values.external.toDouble();
    final num rss = values.rss.toDouble();
    final bool isGced = values.isGC;

    // Alpha filled stacked:
    final num memorySystemAndOther = values.adbMemoryInfo.system.toDouble() +
        values.adbMemoryInfo.other.toDouble(); // Purple-ish
    final num memoryCode = values.adbMemoryInfo.code.toDouble(); // Gray Purple
    final num memoryNativeHeap =
        values.adbMemoryInfo.nativeHeap.toDouble(); // Blue-ish
    final num memoryJavaHeap =
        values.adbMemoryInfo.javaHeap.toDouble(); // Green-ish
    final num memoryStack = values.adbMemoryInfo.stack.toDouble(); // White-ish
    final num memoryGraphics =
        values.adbMemoryInfo.graphics.toDouble(); // Orangy

    final num memoryTotal =
        values.adbMemoryInfo.total.toDouble(); // dashed line

    final TextPainter painter = type == ChartType.DartHeaps
        ? PainterUtils.create(null, _titlesDartVm, textColor, fontSize)
        : PainterUtils.create(null, _titlesAndroid, textColor, fontSize);

    painter.textAlign = TextAlign.left;

    final timestampFormatted =
        _timestampFormatter.getFormattedValue1(timestampAsInt.toDouble());

    // Compute the values of each point for a particular x position (timestamp).
    final TextPainter painterValues = type == ChartType.DartHeaps
        ? PainterUtils.create(
            null,
            '$timestampFormatted\n'
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
            '$timestampFormatted\n'
            '${_formatter.getFormattedValue1(memoryTotal)}\n'
            '${_formatter.getFormattedValue1(memorySystemAndOther)}\n'
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

    // Compute avg text line height from the painter's height
    // of the marker text after layout, divided by # of lines
    // in the TextPainter.
    final double avgLineHeight = painter.height /
        (type == ChartType.DartHeaps
            ? _titlesDartVmLines
            : _titlesAndroidLines);
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
      avgLineHeight,
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

  static const _titlesDartVm = 'Time\n'
      'Capacity\n'
      'Used\n'
      'External\n'
      'RSS\n'
      'GC';

  final int _titlesDartVmLines = _titlesDartVm.split('\n').length;

  // These are the alpha blended values.
  final List<Color> _dartVMColors = [
    // TODO(terry): Dash crashes Canvas unimplemented in Flutter Web
    //              use a green color on Web see Flutter issue/49882.
    kIsWeb
        ? const Color(0xff00ff00)
        : ColorUtils.GRAY, // Total dashed line (Capacity)
    const Color(0xff315a69), // Aqua (Used)
    const Color(0xff77aed5), // Light-Blue (External)
  ];

  static const _titlesAndroid = 'Time\n'
      'Total\n'
      'Other\n'
      'Code\n'
      'Native Heap\n'
      'Java Heap\n'
      'Stack\n'
      'Graphics';

  final int _titlesAndroidLines = _titlesAndroid.split('\n').length;

  // These are the alpha blended values.
  final List<Color> _androidColors = [
    // TODO(terry): Dash crashes Canvas unimplemented in Flutter Web
    //              use a green color on Web see Flutter issue/49882.
    kIsWeb
        ? const Color(0xff00ff00)
        : ColorUtils.WHITE, // Total dashed line (Total)
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
    double swatchYOffset,
  ) {
    const dashDrawWidth = 4.0;
    const dashSkipWidth = 2.0;

    const swatchHeight = 8.0;
    const swatchWidth = 10.0;
    const swatchXOffset = 12.0;
    final swatchYHalfOffset = swatchYOffset ~/ 2.0;

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
    yOffset = pos.dy + swatchYOffset * 2 + 2;

    paint.style = PaintingStyle.fill;
    for (var index = 1; index < colors.length; index++) {
      paint.color = colors[index];
      canvas.drawRect(
        Rect.fromLTWH(xOffset, yOffset, swatchWidth, swatchHeight),
        paint,
      );
      yOffset += swatchYOffset;
    }
  }
}

/// Listener finds the nearest data-point (Entry) that matches the click
/// position in a chart based on the ChartType stored in the SelectedDataPoint.
class DataPointSelectedistener implements OnChartValueSelectedListener {
  DataPointSelectedistener(this._selectedDataPoint);

  final SelectedDataPoint _selectedDataPoint;

  @override
  void onNothingSelected() {}

  @override
  void onValueSelected(Entry e, Highlight h) {
    _selectedDataPoint.entry = e;
    _computeSelection(e);
  }

  int _binarySearch(List<HeapSample> orderedByTimestamp, int xValueTimestamp) {
    int min = 0;
    int max = orderedByTimestamp.length - 1;

    while (min <= max) {
      final mid = ((min + max) / 2).floor();
      if (xValueTimestamp == orderedByTimestamp[mid].timestamp) {
        return mid;
      } else if (xValueTimestamp < orderedByTimestamp[mid].timestamp) {
        max = mid - 1;
      } else {
        min = mid + 1;
      }
    }

    return -1;
  }

  /// Find the raw data (HeapSample) that matches the chart's clicked on data
  /// point Entry. The Entry only has the x, y position (x being the timestamp).
  /// So, using the timestamp find for the raw HeapSample that represents this
  /// timeseries entry.
  void _computeSelection(Entry e) {
    final controller = _selectedDataPoint.memoryController;
    final data = controller.memoryTimeline.data;
    final start = controller.memoryTimeline.startingIndex;

    final oldSample = controller.getSelectedSample(_selectedDataPoint.type);

    // Assume datapoint doesn't point to a sample.
    controller.setSelectedSample(_selectedDataPoint.type, null);

    final timestamp = e.x.toInt();

    // Is the marker being displayed in the visible range?
    if (timestamp > data[start].timestamp) {
      // Marker is visible, just return.
      if (oldSample?.timestamp == timestamp) {
        controller.setSelectedSample(_selectedDataPoint.type, oldSample);
      }

      final foundIndex = _binarySearch(data, timestamp);
      // If found, return new selectable data point and display new marker.
      if (foundIndex != -1) {
        controller.setSelectedSample(_selectedDataPoint.type, data[foundIndex]);
      }
    }
  }
}
