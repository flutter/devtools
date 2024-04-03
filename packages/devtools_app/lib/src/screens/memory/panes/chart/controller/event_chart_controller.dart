// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';

import '../../../../../shared/charts/chart_controller.dart';
import '../../../../../shared/charts/chart_trace.dart' as trace;
import '../../../framework/connected/memory_controller.dart';

/// VM's GCs are displayed in a smaller glyph and closer to the heap graph.
const visibleVmEvent = 0.4;

/// Flutter events and user custom events.
const extensionEvent = 3.7;

/// Event to display in the event pane (User initiated GC, snapshot,
/// automatic snapshot, etc.)
const visibleEvent = 2.4;

/// Monitor events Y axis.
const visibleMonitorEvent = 1.4;

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum EventsTraceName {
  extensionEvents,
  snapshot,
  autoSnapshot,
  manualGC,
  monitor,
  monitorReset,
  gc,
}

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
    final dataLength =
        _memoryController.controllers.chart.memoryTimeline.data.length;

    final dataRange =
        _memoryController.controllers.chart.memoryTimeline.data.getRange(
      chartDataLength,
      dataLength,
    );

    dataRange.forEach(addSample);
  }

  /// Loads all heap samples (live data or offline).
  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.controllers.chart.paused.value) return;

    addTimestamp(sample.timestamp);

    if (sample.isGC) {
      // Plot the VM GC on the VmEvent trace with a fixed Y coordinate.
      addDataToTrace(
        EventsTraceName.gc.index,
        trace.Data(sample.timestamp, visibleVmEvent),
      );
    }
    final events = sample.memoryEventInfo;
    if (events.hasExtensionEvents) {
      final data = trace.DataAggregate(
        sample.timestamp,
        extensionEvent,
        (events.extensionEvents?.theEvents ?? []).length,
      );
      addDataToTrace(EventsTraceName.extensionEvents.index, data);
    }

    // User events snapshot, auto-snapshot, manual GC, are plotted on the top-line
    // of the event pane (visible Events).
    final data = trace.Data(
      sample.timestamp,
      visibleEvent,
    );

    if (events.isEventGC) {
      // Plot manual requested GC on the visibleEvent Y coordinate.
      addDataToTrace(EventsTraceName.manualGC.index, data);
    }

    if (events.isEventSnapshot) {
      // Plot snapshot on the visibleEvent Y coordinate.
      addDataToTrace(EventsTraceName.snapshot.index, data);
    }

    if (events.isEventSnapshotAuto) {
      // Plot auto-snapshot on the visibleEvent Y coordinate.
      addDataToTrace(EventsTraceName.autoSnapshot.index, data);
    }

    if (sample.memoryEventInfo.isEventAllocationAccumulator) {
      final allocationEvent = events.allocationAccumulator!;
      final data = trace.Data(
        sample.timestamp,
        visibleMonitorEvent,
      );
      if (allocationEvent.isReset) {
        addDataToTrace(EventsTraceName.monitorReset.index, data);
      } else if (allocationEvent.isStart) {
        addDataToTrace(EventsTraceName.monitor.index, data);
      }
    }
  }

  void addDataToTrace(int traceIndex, trace.Data data) {
    this.trace(traceIndex).addDatum(data);
  }
}
