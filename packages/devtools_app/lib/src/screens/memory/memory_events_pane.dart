// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../charts/chart.dart';
import '../../charts/chart_controller.dart';
import '../../charts/chart_trace.dart' as trace;
import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/theme.dart';
import 'memory_controller.dart';
import 'memory_timeline.dart';

// TODO(terry): Consider custom painter?
const _base = 'assets/img/legend/';
const snapshotManualLegend = '${_base}snapshot_manual_glyph.png';
const snapshotAutoLegend = '${_base}snapshot_auto_glyph.png';
const monitorLegend = '${_base}monitor_glyph.png';
const resetDarkLegend = '${_base}reset_glyph_dark.png';
const resetLightLegend = '${_base}reset_glyph_light.png';
const gcManualLegend = '${_base}gc_manual_glyph.png';
const gcVMLegend = '${_base}gc_vm_glyph.png';
const eventLegend = '${_base}event_glyph.png';
const eventsLegend = '${_base}events_glyph.png';

/// Events trace name displayed
const manualSnapshotLegendName = 'Snapshot';
const autoSnapshotLegendName = 'Auto';
const monitorLegendName = 'Monitor';
const resetLegendName = 'Reset';
const vmGCLegendName = 'GC VM';
const manualGCLegendName = 'Manual';
const eventLegendName = 'Event';
const eventsLegendName = 'Events';

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
    if (events.hasExtensionEvents) {
      final data = trace.DataAggregate(
        sample.timestamp,
        MemoryEventsPaneState.extensionEvent,
        (events.extensionEvents?.theEvents ?? []).length,
      );
      addDataToTrace(TraceName.extensionEvents.index, data);
    }

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
      final allocationEvent = events.allocationAccumulator!;
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
  const MemoryEventsPane(this.chartController, {Key? key}) : super(key: key);

  final EventChartController chartController;

  @override
  MemoryEventsPaneState createState() => MemoryEventsPaneState();
}

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum TraceName {
  extensionEvents,
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

  bool _initialized = false;

  /// Controller for managing memory collection.
  late MemoryController _memoryController;

  /// Note: The event pane is a fixed size chart (y-axis does not scale). The
  ///       Y-axis fixed range is (visibleVmEvent to extensionEvent) e.g.,
  ///
  ///                         ____________________
  ///         extensionEvent -|            *  (3.7)
  ///                         |         *  (2.4)
  ///                         |      *  (1.4)
  ///         visibleVmEvent -|   *  (0.4)
  ///                    0.0 _|___________________
  ///
  ///       The *s in the above chart are plotted at each y position (3.7, 2.4, 1.4, 0.4).
  ///       Their y-position is such that the symbols won't overlap.
  /// TODO(terry): Consider a better solution e.g., % in the Y-axis.

  /// Flutter events and user custom events.
  static const extensionEvent = 3.7;

  /// Event to display in the event pane (User initiated GC, snapshot,
  /// automatic snapshot, etc.)
  static const visibleEvent = 2.4;

  /// Monitor events Y axis.
  static const visibleMonitorEvent = 1.4;

  /// VM's GCs are displayed in a smaller glyph and closer to the heap graph.
  static const visibleVmEvent = 0.4;

  MemoryTimeline get _memoryTimeline => _memoryController.memoryTimeline;

  @override
  void initState() {
    super.initState();

    // Line chart fixed Y range.
    _chartController.setFixedYRange(visibleVmEvent, extensionEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newMemoryController = Provider.of<MemoryController>(context);
    if (_initialized && newMemoryController == _memoryController) return;
    _initialized = true;
    _memoryController = newMemoryController;

    final themeData = Theme.of(context);

    cancelListeners();

    setupTraces(isDarkMode: themeData.isDarkTheme);
    _chartController.setupData();

    // Monitor heap samples.
    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      final value = _memoryTimeline.sampleAddedNotifier.value;
      if (value == null) return;
      setState(() {
        _processHeapSample(value);
      });
    });

    // Monitor event fired.
    addAutoDisposeListener(_memoryTimeline.eventNotifier, () {
      setState(() {
        // TODO(terry): New event received.
        //_processHeapSample(_memoryTimeline.eventNotifier.value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController.timestamps.isNotEmpty) {
      return Chart(_chartController);
    }

    return const SizedBox(width: denseSpacing);
  }

  void setupTraces({bool isDarkMode = true}) {
    if (_chartController.traces.isNotEmpty) {
      assert(_chartController.traces.length == TraceName.values.length);

      final extensionEventsIndex = TraceName.extensionEvents.index;
      assert(
        _chartController.trace(extensionEventsIndex).name ==
            TraceName.values[extensionEventsIndex].toString(),
      );

      final snapshotIndex = TraceName.snapshot.index;
      assert(
        _chartController.trace(snapshotIndex).name ==
            TraceName.values[snapshotIndex].toString(),
      );

      final autoSnapshotIndex = TraceName.autoSnapshot.index;
      assert(
        _chartController.trace(autoSnapshotIndex).name ==
            TraceName.values[autoSnapshotIndex].toString(),
      );

      final manualGCIndex = TraceName.manualGC.index;
      assert(
        _chartController.trace(manualGCIndex).name ==
            TraceName.values[manualGCIndex].toString(),
      );

      final monitorIndex = TraceName.monitor.index;
      assert(
        _chartController.trace(monitorIndex).name ==
            TraceName.values[monitorIndex].toString(),
      );

      final monitorResetIndex = TraceName.monitorReset.index;
      assert(
        _chartController.trace(monitorResetIndex).name ==
            TraceName.values[monitorResetIndex].toString(),
      );

      final gcIndex = TraceName.gc.index;
      assert(
        _chartController.trace(gcIndex).name ==
            TraceName.values[gcIndex].toString(),
      );

      return;
    }

    final extensionEventsIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.purpleAccent[100]!,
        colorAggregate: Colors.purpleAccent[400],
        symbol: trace.ChartSymbol.filledTriangle,
        height: 20,
        width: 20,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: TraceName.extensionEvents.toString(),
    );
    assert(extensionEventsIndex == TraceName.extensionEvents.index);
    assert(
      _chartController.trace(extensionEventsIndex).name ==
          TraceName.values[extensionEventsIndex].toString(),
    );

    final snapshotIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.green,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: TraceName.snapshot.toString(),
    );
    assert(snapshotIndex == TraceName.snapshot.index);
    assert(
      _chartController.trace(snapshotIndex).name ==
          TraceName.values[snapshotIndex].toString(),
    );

    // Auto-snapshot
    final autoSnapshotIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.red,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: TraceName.autoSnapshot.toString(),
    );
    assert(autoSnapshotIndex == TraceName.autoSnapshot.index);
    assert(
      _chartController.trace(autoSnapshotIndex).name ==
          TraceName.values[autoSnapshotIndex].toString(),
    );

    // Manual GC
    final manualGCIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.blue,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: TraceName.manualGC.toString(),
    );
    assert(manualGCIndex == TraceName.manualGC.index);
    assert(
      _chartController.trace(manualGCIndex).name ==
          TraceName.values[manualGCIndex].toString(),
    );

    final mainMonitorColor =
        isDarkMode ? Colors.yellowAccent : Colors.yellowAccent.shade400;

    // Monitor
    final monitorIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: mainMonitorColor,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: TraceName.monitor.toString(),
    );
    assert(monitorIndex == TraceName.monitor.index);
    assert(
      _chartController.trace(monitorIndex).name ==
          TraceName.values[monitorIndex].toString(),
    );

    final monitorResetIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics.concentric(
        color: Colors.grey[600]!,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
        concentricCenterColor: mainMonitorColor,
        concentricCenterDiameter: 4,
      ),
      name: TraceName.monitorReset.toString(),
    );
    assert(monitorResetIndex == TraceName.monitorReset.index);
    assert(
      _chartController.trace(monitorResetIndex).name ==
          TraceName.values[monitorResetIndex].toString(),
    );

    // VM GC
    final gcIndex = _chartController.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.blue,
        symbol: trace.ChartSymbol.disc,
        diameter: 4,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: TraceName.gc.toString(),
    );
    assert(gcIndex == TraceName.gc.index);
    assert(
      _chartController.trace(gcIndex).name ==
          TraceName.values[gcIndex].toString(),
    );

    assert(_chartController.traces.length == TraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.isPaused) return;
    _chartController.addSample(sample);
  }
}
