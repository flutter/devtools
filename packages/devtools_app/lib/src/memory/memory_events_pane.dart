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

class EventChartController extends ChartController {
  EventChartController(this._memoryController)
      : super(
          displayYLabels: false,
          displayXAxis: false,
          displayXLabels: false,
          name: 'Event Pane',
        );

  final MemoryController _memoryController;

  // TODO(terry): Only load max visible data collected, when pruning of data
  //              charted is added.
  /// Preload any existing data collected but not in the chart.
  @override
  void setupData() {
    final chartDataLength = timestampsLength;
    final dataLength = _memoryController.memoryTimeline.data.length;

    final dataRange = _memoryController.memoryTimeline.data.getRange(
      chartDataLength,
      dataLength,
    );

    dataRange.forEach(addSample);
  }

  /// Loads all heap samples (live data or offline).
  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.paused.value) return;

    addTimestamp(sample.timestamp);

    if (sample.isGC) {
      // Plot the VM GC on the VmEvent trace with a fixed Y coordinate.
      addDataToTrace(
        TraceName.gc.index,
        trace.Data(sample.timestamp, MemoryEventsPaneState.visibleVmEvent),
      );
    }
    final events = sample.memoryEventInfo;
    // User events snapshot, auto-snapshot, manual GC, are plotted on the top-line
    // of the event pane (visible Events).
    final data = trace.Data(
      sample.timestamp,
      MemoryEventsPaneState.visibleEvent,
    );

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
      final data = trace.Data(
        sample.timestamp,
        MemoryEventsPaneState.visibleMonitorEvent,
      );
      if (allocationEvent.isReset) {
        addDataToTrace(TraceName.monitorReset.index, data);
      } else if (allocationEvent.isStart) {
        addDataToTrace(TraceName.monitor.index, data);
      }
    }
  }

  void addDataToTrace(int traceIndex, trace.Data data) {
    this.trace(traceIndex).addDatum(data);
  }
}

class MemoryEventsPane extends StatefulWidget {
  const MemoryEventsPane(this.chartController);

  final EventChartController chartController;

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
  /// Controller attached to this chart.
  EventChartController get _chartController => widget.chartController;

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
    super.initState();

    // Line chart fixed Y range.
    _chartController.setFixedYRange(visibleVmEvent, visibleEvent);

    setupTraces();
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
    _chartController.setupData();

    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      setState(() {
        _processHeapSample(_memoryTimeline.sampleAddedNotifier.value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController != null) {
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

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.isPaused) return;
    _chartController.addSample(sample);
  }
}
