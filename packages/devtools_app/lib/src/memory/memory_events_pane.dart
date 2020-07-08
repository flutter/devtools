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

  /// Override onNothingSelected and onValueSelected for selectionListener.
  @override
  void onNothingSelected() {
    // TODO: implement onNothingSelected
    print('>>>> onNothingSelected');
  }

  @override
  void onValueSelected(Entry e, Highlight h) {
    // TODO: implement onValueSelected
    print('>>>> onValueSelected');
  }

  /// Point to keep Y axis from scaling, entries invisible foreground color of
  /// points are background color of the event pane.
  ScatterDataSet _ghostTopLineSet;

  /// VM is GCing.
  ScatterDataSet _gcVmDataSet;

  /// Used to signal start allocation monitoring
  ScatterDataSet _allocationStartSet;

  /// Montoring continuing...
  ScatterDataSet _allocationContinueSet;

  /// Reset allocation accumulators
  ScatterDataSet _allocationResetSet;

  /// GC initiated by user pressing GC button.
  ScatterDataSet _gcUserDataSet;

  /// User initiated snapshot.
  ScatterDataSet _snapshotDataSet;

  /// Automatically initiated snapshot.
  ScatterDataSet _snapshotAutoDataSet;

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
    _gcVmDataSet.setScatterShapeHoleColor(ColorUtils.HOLO_BLUE_DARK);

    // Dataset for user generated GC.
    _gcUserDataSet = ScatterDataSet(eventsData.gcUser, 'User GC');
    _gcUserDataSet.setScatterShape(ScatterShape.CIRCLE);
    _gcUserDataSet.setScatterShapeHoleRadius(.6);
    _gcUserDataSet.setScatterShapeHoleColor(ColorUtils.HOLO_BLUE_LIGHT);

    // Dataset for user generated Snapshot.
    _snapshotDataSet = ScatterDataSet(eventsData.snapshot, 'Snapshot');
    _snapshotDataSet.setScatterShape(ScatterShape.TRIANGLE);
    _snapshotDataSet.setScatterShapeHoleRadius(.6);
    _snapshotDataSet.setScatterShapeHoleColor(ColorUtils.HOLO_GREEN_DARK);
    _snapshotDataSet.setColor1(ColorUtils.HOLO_GREEN_DARK);

    _allocationStartSet = ScatterDataSet(eventsData.monitorStart, 'Monitor Start');
    _allocationStartSet.setScatterShape(ScatterShape.SQUARE);
    _allocationStartSet.setScatterShapeSize(10);
    _allocationStartSet.setColor1(ColorUtils.YELLOW);

    _allocationContinueSet = ScatterDataSet(eventsData.monitorContinues, 'Monitor Continue');
    _allocationContinueSet.setScatterShape(ScatterShape.SQUARE);
    _allocationContinueSet.setScatterShapeSize(8);
    _allocationContinueSet.setColor2(ColorUtils.YELLOW, 30);

    _allocationResetSet = ScatterDataSet(eventsData.monitorReset, 'Monitor Reset');
    _allocationResetSet.setScatterShape(ScatterShape.CIRCLE);
    _allocationResetSet.setScatterShapeHoleRadius(.8);
    _allocationResetSet.setScatterShapeHoleColor(ColorUtils.YELLOW);
    _allocationResetSet.setColor2(ColorUtils.YELLOW, 110);

    // Datset for automatic Snapshot.
    _snapshotAutoDataSet = ScatterDataSet(
      eventsData.snapshotAuto,
      'Snapshot-Auto',
    );
    _snapshotAutoDataSet.setScatterShape(ScatterShape.TRIANGLE);
    _snapshotAutoDataSet.setScatterShapeHoleRadius(.6);
    _snapshotAutoDataSet.setScatterShapeHoleColor(ColorUtils.HOLO_RED_LIGHT);
    _snapshotAutoDataSet.setColor1(ColorUtils.HOLO_RED_LIGHT);

    // create a data object with the data sets
    _controller.data = ScatterData.fromList([
      _ghostTopLineSet,
      _gcVmDataSet,
      _allocationStartSet,
      _allocationContinueSet,
      _allocationResetSet,
      _gcUserDataSet,
      _snapshotDataSet,
      _snapshotAutoDataSet,
    ]);
    _controller.data.setDrawValues(false);
  }

  /// Loads all heap samples (live data or offline).
  void _processAndUpdate([bool reloadAllData = false]) {
    setState(() {
      // Display new events in the pane.
      _updateEventPane();
    });
  }

  /// Display any newly received events in the chart.
  void _updateEventPane() {
    setState(() {
      _controller.data = ScatterData.fromList([
        _gcVmDataSet,
        _allocationStartSet,
        _allocationContinueSet,
        _allocationResetSet,
        _gcUserDataSet,
        _snapshotDataSet,
        _snapshotAutoDataSet,
      ]);

      // Received new samples ready to plot, signal data has changed.
      _gcVmDataSet.notifyDataSetChanged();
      _allocationStartSet.notifyDataSetChanged();
      _allocationContinueSet.notifyDataSetChanged();
      _allocationResetSet.notifyDataSetChanged();
      _gcUserDataSet.notifyDataSetChanged();
      _snapshotDataSet.notifyDataSetChanged();
      _snapshotAutoDataSet.notifyDataSetChanged();
    });
  }
}
