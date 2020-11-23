// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/chart.dart';
import '../charts/chart_controller.dart';
import '../charts/chart_trace.dart' as trace;
import '../theme.dart';

import 'memory_controller.dart';
import 'memory_timeline.dart';

class MemoryEventsPane extends StatefulWidget {
  const MemoryEventsPane(this.chartController);

  final ChartController chartController;

  @override
  MemoryEventsPaneState createState() => MemoryEventsPaneState();
}

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum TraceName {
  snapshot,
  autoSnapshot,
  manualGC,
  monitor,
  monitorReset,
  gc,
}

class MemoryEventsPaneState extends State<MemoryEventsPane>
    with AutoDisposeMixin {
  /// Controller attached to the chart.
  ChartController get _chartController => widget.chartController;

  /// Controller for managing memory collection.
  MemoryController _memoryController;

  /// Event to display in the event pane (User initiated GC, snapshot,
  /// automatic snapshot, etc.)
  static const visibleEvent = 2.4;

  /// Monitor events Y axis.
  static const visibleMonitorEvent = 1.4;

  /// VM's GCs are displayed in a smaller glyph and closer to the heap graph.
  static const visibleVmEvent = 0.4;

  MemoryTimeline get _memoryTimeline => _memoryController.memoryTimeline;

  ColorScheme colorScheme;

  @override
  void initState() {
    // Line chart fixed Y range.
    _chartController.setFixedYRange(visibleVmEvent, visibleEvent);

    setupTraces();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _memoryController = Provider.of<MemoryController>(context);

    // TODO(jacobr): this is an ugly way to be using the theme. It would be
    // better if the controllers weren't involved with the color scheme.
    colorScheme = Theme.of(context).colorScheme;

    cancel();

    setupTraces();
    setupChartData();

    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      _setupEventsChartData(colorScheme);
      setState(() {
        _processHeapSample(_memoryTimeline.sampleAddedNotifier.value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController != null) {
      colorScheme = Theme.of(context).colorScheme;
      _setupEventsChartData(colorScheme);

      if (_chartController.timestamps.isNotEmpty) {
        return Chart(_chartController);
      }
    }

    return const SizedBox(width: denseSpacing);
  }

  void setupTraces() {
    if (_chartController.traces.isNotEmpty) {
      assert(_chartController.traces.length == TraceName.values.length);

      final snapshotIndex = TraceName.snapshot.index;
      assert(_chartController.trace(snapshotIndex).name ==
          TraceName.values[snapshotIndex].toString());

      final autoSnapshotIndex = TraceName.autoSnapshot.index;
      assert(_chartController.trace(autoSnapshotIndex).name ==
          TraceName.values[autoSnapshotIndex].toString());

      final manualGCIndex = TraceName.manualGC.index;
      assert(_chartController.trace(manualGCIndex).name ==
          TraceName.values[manualGCIndex].toString());

      final monitorIndex = TraceName.monitor.index;
      assert(_chartController.trace(monitorIndex).name ==
          TraceName.values[monitorIndex].toString());

      final monitorResetIndex = TraceName.monitorReset.index;
      assert(_chartController.trace(monitorResetIndex).name ==
          TraceName.values[monitorResetIndex].toString());

      final gcIndex = TraceName.gc.index;
      assert(_chartController.trace(gcIndex).name ==
          TraceName.values[gcIndex].toString());

      return;
    }

    final snapshotIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.green,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: visibleEvent,
      ),
      name: TraceName.snapshot.toString(),
    );
    assert(snapshotIndex == TraceName.snapshot.index);
    assert(_chartController.trace(snapshotIndex).name ==
        TraceName.values[snapshotIndex].toString());

    // Auto-snapshot
    final autoSnapshotIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.red,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: visibleEvent,
      ),
      name: TraceName.autoSnapshot.toString(),
    );
    assert(autoSnapshotIndex == TraceName.autoSnapshot.index);
    assert(_chartController.trace(autoSnapshotIndex).name ==
        TraceName.values[autoSnapshotIndex].toString());

    // Manual GC
    final manualGCIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.blue,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: visibleEvent,
      ),
      name: TraceName.manualGC.toString(),
    );
    assert(manualGCIndex == TraceName.manualGC.index);
    assert(_chartController.trace(manualGCIndex).name ==
        TraceName.values[manualGCIndex].toString());

    // Monitor
    final monitorIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.yellow,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: visibleEvent,
      ),
      name: TraceName.monitor.toString(),
    );
    assert(monitorIndex == TraceName.monitor.index);
    assert(_chartController.trace(monitorIndex).name ==
        TraceName.values[monitorIndex].toString());

    final monitorResetIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.yellowAccent,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: visibleEvent,
      ),
      name: TraceName.monitorReset.toString(),
    );
    assert(monitorResetIndex == TraceName.monitorReset.index);
    assert(_chartController.trace(monitorResetIndex).name ==
        TraceName.values[monitorResetIndex].toString());

    // VM GC
    final gcIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.blue,
        symbol: trace.ChartSymbol.disc,
        diameter: 4,
        fixedMinY: visibleVmEvent,
        fixedMaxY: visibleEvent,
      ),
      name: TraceName.gc.toString(),
    );
    assert(gcIndex == TraceName.gc.index);
    assert(_chartController.trace(gcIndex).name ==
        TraceName.values[gcIndex].toString());

    assert(_chartController.traces.length == TraceName.values.length);
  }

  /// Pulls the visible EventSamples added as trace data to actual data list to be
  /// plotted.
  void _setupEventsChartData(ColorScheme colorScheme) {
    final eventsData = _memoryController.memoryTimeline.eventsChartData;

    // Ghosting dataset, prevents auto-scaling of the Y-axis.
/*
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
*/
  }

  // TODO(terry): Only load max visible data collected, when pruning of data
  //              charted is added.
  /// Preload any existing data collected but not in the chart.
  void setupChartData() {
    final chartDataLength = _chartController.timestamps.length;
    final liveDataLength = _memoryTimeline.liveData.length;

    final liveRange = _memoryTimeline.liveData.getRange(
      chartDataLength,
      liveDataLength,
    );

    liveRange.forEach(_addSampleToChart);
  }

  /// Loads all heap samples (live data or offline).
  void _addSampleToChart(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.paused.value) return;

    _chartController.timestamps.add(sample.timestamp);

    if (sample.isGC) {
      // Plot the VM GC on the VmEvent trace with a fixed Y coordinate.
      addDataToTrace(
        TraceName.gc.index,
        trace.Data(sample.timestamp, visibleVmEvent),
      );
    }
    final events = sample.memoryEventInfo;
    // User events snapshot, auto-snapshot, manual GC, are plotted on the top-line
    // of the event pane (visible Events).
    final data = trace.Data(sample.timestamp, visibleEvent);

    if (events.isEventGC) {
      // Plot manual requested GC on the visibleEvent Y coordinate.
      addDataToTrace(TraceName.manualGC.index, data);
    }

    if (events.isEventSnapshot) {
      // Plot snapshot on the visibleEvent Y coordinate.
      addDataToTrace(TraceName.snapshot.index, data);
    }

    if (events.isEventSnapshotAuto) {
      // Plot auto-snapshot on the visibleEvent Y coordinate.
      addDataToTrace(TraceName.autoSnapshot.index, data);
    }

    if (sample.memoryEventInfo.isEventAllocationAccumulator) {
      final allocationEvent = events.allocationAccumulator;
      final data = trace.Data(sample.timestamp, visibleMonitorEvent);
      if (allocationEvent.isReset) {
        addDataToTrace(TraceName.monitorReset.index, data);
      } else if (allocationEvent.isStart) {
        addDataToTrace(TraceName.monitor.index, data);
      }
    }
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.paused.value) return;
    _addSampleToChart(sample);
  }

  void addDataToTrace(int traceIndex, trace.Data data) {
    _chartController.trace(traceIndex).addDatum(data);
  }
}
