// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:mp_chart/mp/chart/scatter_chart.dart';
import 'package:mp_chart/mp/controller/scatter_chart_controller.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/scatter_data.dart';
import 'package:mp_chart/mp/core/data_set/scatter_data_set.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/scatter_shape.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/enums/y_axis_label_position.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../theme.dart';

import 'memory_controller.dart';
import 'memory_timeline.dart';

class MemoryEventsPane extends StatefulWidget {
  @override
  MemoryEventsPaneState createState() => MemoryEventsPaneState();
}

class MemoryEventsPaneState extends State<MemoryEventsPane>
    with AutoDisposeMixin, OnChartValueSelectedListener {
  ScatterChartController _controller;

  MemoryController _memoryController;

  MemoryTimeline get _memoryTimeline => _memoryController.memoryTimeline;

  ColorScheme colorScheme;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _memoryController = Provider.of<MemoryController>(context);
    // TODO(jacobr): this is an ugly way to be using the theme. It would be
    // better if the controllers weren't involved with the color scheme.
    colorScheme = Theme.of(context).colorScheme;

    _initController(colorScheme);

    cancel();

    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      _setupEventsChartData(colorScheme);
      _processAndUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) {
      colorScheme = Theme.of(context).colorScheme;
      _setupEventsChartData(colorScheme);
      final hasData = _controller.data.dataSets.first.getEntryCount() > 0;
      if (hasData) {
        return Container(child: ScatterChart(_controller), height: 50);
      }
    }

    return const SizedBox(width: denseSpacing);
  }

  void _initController(ColorScheme colorScheme) {
    final desc = Description()..enabled = false;
    _controller ??= ScatterChartController(
      axisLeftSettingFunction: (axisLeft, controller) {
        axisLeft
          ..position = YAxisLabelPosition.OUTSIDE_CHART
          ..drawGridLines = false
          ..granularityEnabled = true
          // Set to baseline min and auto track max axis range.
          ..setStartAtZero(true);
      },
      axisRightSettingFunction: (axisRight, controller) {
        axisRight.enabled = false;
      },
      legendSettingFunction: (legend, controller) {
        legend.enabled = false;
      },
      xAxisSettingFunction: (xAxis, controller) {
        xAxis
          ..enabled = true
          ..position = XAxisPosition.TOP
          // Hide the text (same as background).
          ..textColor = colorScheme.defaultBackgroundColor
          ..drawAxisLine = true
          ..drawGridLines = true;
      },
      backgroundColor: colorScheme.defaultBackgroundColor,
      maxVisibleCount: 1000,
      maxHighlightDistance: 50,
      selectionListener: this,
      description: desc,
      minOffset: 0,
    );

    _controller.setViewPortOffsets(
        defaultSpacing * 3, denseSpacing, defaultSpacing, 0);
  }

  final datasets = List<ScatterDataSet>.generate(
    EventDataSets.values.length,
    (int) => null,
  );

  /// Point to keep Y axis from scaling, entries invisible foreground color of
  /// points are background color of the event pane.
  ScatterDataSet get _ghostTopLineSet =>
      datasets[EventDataSets.ghostsSet.index];
  set _ghostTopLineSet(ScatterDataSet dataset) {
    datasets[EventDataSets.ghostsSet.index] = dataset;
  }

  /// VM is GCing.
  ScatterDataSet get _gcVmDataSet => datasets[EventDataSets.gcVmSet.index];
  set _gcVmDataSet(ScatterDataSet dataset) {
    datasets[EventDataSets.gcVmSet.index] = dataset;
  }

  /// Used to signal start allocation monitoring
  ScatterDataSet get _allocationStartSet =>
      datasets[EventDataSets.monitorStartSet.index];
  set _allocationStartSet(ScatterDataSet dataset) {
    datasets[EventDataSets.monitorStartSet.index] = dataset;
  }

  /// Montoring continuing...
  ScatterDataSet get _allocationContinueSet =>
      datasets[EventDataSets.monitorContinuesSet.index];
  set _allocationContinueSet(ScatterDataSet dataset) {
    datasets[EventDataSets.monitorContinuesSet.index] = dataset;
  }

  /// Reset allocation accumulators
  ScatterDataSet get _allocationResetSet =>
      datasets[EventDataSets.monitorResetSet.index];
  set _allocationResetSet(ScatterDataSet dataset) {
    datasets[EventDataSets.monitorResetSet.index] = dataset;
  }

  /// GC initiated by user pressing GC button.
  ScatterDataSet get _gcUserDataSet => datasets[EventDataSets.gcUserSet.index];
  set _gcUserDataSet(ScatterDataSet dataset) {
    datasets[EventDataSets.gcUserSet.index] = dataset;
  }

  /// User initiated snapshot.
  ScatterDataSet get _snapshotDataSet =>
      datasets[EventDataSets.snapshotSet.index];
  set _snapshotDataSet(ScatterDataSet dataset) {
    datasets[EventDataSets.snapshotSet.index] = dataset;
  }

  /// Automatically initiated snapshot.
  ScatterDataSet get _snapshotAutoDataSet =>
      datasets[EventDataSets.snapshotAutoSet.index];
  set _snapshotAutoDataSet(ScatterDataSet dataset) {
    datasets[EventDataSets.snapshotAutoSet.index] = dataset;
  }

  /// Pulls the visible EventSamples added as trace data to actual data list to be
  /// plotted.
  void _setupEventsChartData(ColorScheme colorScheme) {
    final eventsData = _memoryController.memoryTimeline.eventsChartData;

    // Ghosting dataset, prevents auto-scaling of the Y-axis.
    _ghostTopLineSet = ScatterDataSet(eventsData.ghosts, 'Ghosting Trace');
    _ghostTopLineSet.setScatterShape(ScatterShape.CIRCLE);
    _ghostTopLineSet.setScatterShapeSize(0);

    // Dataset for VM GCs.
    _gcVmDataSet = ScatterDataSet(eventsData.gcVm, 'VM GC');
    _gcVmDataSet.setScatterShape(ScatterShape.CIRCLE);
    _gcVmDataSet.setScatterShapeSize(6);
    _gcVmDataSet.setColor1(ColorUtils.HOLO_BLUE_DARK);

    // Dataset for user generated GC.
    _gcUserDataSet = ScatterDataSet(eventsData.gcUser, 'User GC');
    _gcUserDataSet.setScatterShape(ScatterShape.CIRCLE);
    _gcUserDataSet.setColor1(ColorUtils.HOLO_BLUE_DARK);
    _gcUserDataSet.setScatterShapeHoleRadius(.9);
    _gcUserDataSet.setScatterShapeHoleColor(colorScheme.defaultBackgroundColor);

    // Dataset for user generated Snapshot.
    _snapshotDataSet = ScatterDataSet(eventsData.snapshot, 'Snapshot');
    _snapshotDataSet.setScatterShape(ScatterShape.CIRCLE);
    _snapshotDataSet.setColor1(ColorUtils.HOLO_GREEN_DARK);
    _snapshotDataSet.setScatterShapeHoleRadius(.9);
    _snapshotDataSet
        .setScatterShapeHoleColor(colorScheme.defaultBackgroundColor);

    _allocationStartSet =
        ScatterDataSet(eventsData.monitorStart, 'Monitor Start');
    _allocationStartSet.setScatterShape(ScatterShape.CIRCLE);
    _allocationStartSet.setColor1(ColorUtils.YELLOW);
    _allocationStartSet.setScatterShapeHoleRadius(.9);
    _allocationStartSet
        .setScatterShapeHoleColor(colorScheme.defaultBackgroundColor);

    _allocationContinueSet =
        ScatterDataSet(eventsData.monitorContinues, 'Monitor Continue');
    _allocationContinueSet.setScatterShape(ScatterShape.SQUARE);
    _allocationContinueSet.setScatterShapeSize(8);
    _allocationContinueSet.setColor2(ColorUtils.YELLOW, 30);

    _allocationResetSet =
        ScatterDataSet(eventsData.monitorReset, 'Monitor Reset');
    _allocationResetSet.setScatterShape(ScatterShape.CIRCLE);
    _allocationResetSet.setScatterShapeHoleRadius(.8);
    _allocationResetSet.setScatterShapeHoleColor(ColorUtils.YELLOW);
    _allocationResetSet.setColor2(ColorUtils.YELLOW, 110);

    // Datset for automatic Snapshot.
    _snapshotAutoDataSet = ScatterDataSet(
      eventsData.snapshotAuto,
      'Snapshot-Auto',
    );
    _snapshotAutoDataSet.setScatterShape(ScatterShape.CIRCLE);
    _snapshotAutoDataSet.setColor1(ColorUtils.HOLO_RED_LIGHT);
    _snapshotAutoDataSet.setScatterShapeHoleRadius(.9);
    _snapshotAutoDataSet
        .setScatterShapeHoleColor(colorScheme.defaultBackgroundColor);

    // create a data object with the data sets
    _controller.data = ScatterData.fromList(datasets);
    _controller.data.setDrawValues(false);
  }

  /// Loads all heap samples (live data or offline).
  void _processAndUpdate() {
    setState(() {
      // Display new events in the pane.
      _updateEventPane();
    });
  }

  /// Display any newly received events in the chart.
  void _updateEventPane() {
    setState(() {
      _controller.data = ScatterData.fromList(datasets);

      // Received new samples ready to plot, signal data has changed.
      for (final dataset in datasets) {
        dataset.notifyDataSetChanged();
      }
    });
  }

  @override
  void onNothingSelected() {
    // TODO: implement onNothingSelected
  }

  @override
  void onValueSelected(Entry e, Highlight h) {
    // TODO: implement onValueSelected
  }
}
