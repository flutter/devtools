// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/charts/chart_controller.dart';
import '../../../../../../shared/charts/chart_trace.dart' as chart_trace;
import '../../../../../../shared/charts/chart_trace.dart'
    show ChartType, PaintCharacteristics, ChartSymbol;
import '../../../../shared/primitives/memory_timeline.dart';

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

/// The event pane is a fixed size chart (y-axis does not scale). The
/// Y-axis fixed range is (visibleVmEvent to extensionEvent) e.g.,
///
///                   ____________________
///   extensionEvent -|            *  (3.7)
///                   |         *  (2.4)
///                   |      *  (1.4)
///   visibleVmEvent -|   *  (0.4)
///              0.0 _|___________________
///
/// The *s in the above chart are plotted at each y position (3.7, 2.4, 1.4, 0.4).
/// Their y-position is such that the symbols won't overlap.
class EventChartController extends ChartController {
  EventChartController(this.memoryTimeline, {required this.paused})
      : super(
          displayYLabels: false,
          displayXAxis: false,
          displayXLabels: false,
          name: 'Event Pane',
        ) {
    _setupTraces();
    setFixedYRange(visibleVmEvent, extensionEvent);
    setupData();

    addAutoDisposeListener(memoryTimeline.sampleAdded, () {
      if (memoryTimeline.sampleAdded.value != null) {
        addSample(memoryTimeline.sampleAdded.value!);
      }
    });
  }

  final ValueListenable<bool> paused;
  final MemoryTimeline memoryTimeline;

  @override
  void setupData() {
    final chartDataLength = timestampsLength;
    final dataLength = memoryTimeline.data.length;

    final dataRange = memoryTimeline.data.getRange(
      chartDataLength,
      dataLength,
    );

    dataRange.forEach(addSample);
  }

  void _setupTraces() {
    if (traces.isNotEmpty) {
      assert(traces.length == EventsTraceName.values.length);

      final extensionEventsIndex = EventsTraceName.extensionEvents.index;
      assert(
        trace(extensionEventsIndex).name ==
            EventsTraceName.values[extensionEventsIndex].toString(),
      );

      final snapshotIndex = EventsTraceName.snapshot.index;
      assert(
        trace(snapshotIndex).name ==
            EventsTraceName.values[snapshotIndex].toString(),
      );

      final autoSnapshotIndex = EventsTraceName.autoSnapshot.index;
      assert(
        trace(autoSnapshotIndex).name ==
            EventsTraceName.values[autoSnapshotIndex].toString(),
      );

      final manualGCIndex = EventsTraceName.manualGC.index;
      assert(
        trace(manualGCIndex).name ==
            EventsTraceName.values[manualGCIndex].toString(),
      );

      final monitorIndex = EventsTraceName.monitor.index;
      assert(
        trace(monitorIndex).name ==
            EventsTraceName.values[monitorIndex].toString(),
      );

      final monitorResetIndex = EventsTraceName.monitorReset.index;
      assert(
        trace(monitorResetIndex).name ==
            EventsTraceName.values[monitorResetIndex].toString(),
      );

      final gcIndex = EventsTraceName.gc.index;
      assert(
        trace(gcIndex).name == EventsTraceName.values[gcIndex].toString(),
      );

      return;
    }

    final extensionEventsIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.purpleAccent[100]!,
        colorAggregate: Colors.purpleAccent[400],
        symbol: ChartSymbol.filledTriangle,
        height: 20,
        width: 20,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: EventsTraceName.extensionEvents.toString(),
    );
    assert(extensionEventsIndex == EventsTraceName.extensionEvents.index);
    assert(
      trace(extensionEventsIndex).name ==
          EventsTraceName.values[extensionEventsIndex].toString(),
    );

    final snapshotIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.green,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: EventsTraceName.snapshot.toString(),
    );
    assert(snapshotIndex == EventsTraceName.snapshot.index);
    assert(
      trace(snapshotIndex).name ==
          EventsTraceName.values[snapshotIndex].toString(),
    );

    // Auto-snapshot
    final autoSnapshotIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.red,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: EventsTraceName.autoSnapshot.toString(),
    );
    assert(autoSnapshotIndex == EventsTraceName.autoSnapshot.index);
    assert(
      trace(autoSnapshotIndex).name ==
          EventsTraceName.values[autoSnapshotIndex].toString(),
    );

    // Manual GC
    final manualGCIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.blue,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: EventsTraceName.manualGC.toString(),
    );
    assert(manualGCIndex == EventsTraceName.manualGC.index);
    assert(
      trace(manualGCIndex).name ==
          EventsTraceName.values[manualGCIndex].toString(),
    );

    final mainMonitorColor = Colors.yellowAccent.shade400;

    // Monitor
    final monitorIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: mainMonitorColor,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: EventsTraceName.monitor.toString(),
    );
    assert(monitorIndex == EventsTraceName.monitor.index);
    assert(
      trace(monitorIndex).name ==
          EventsTraceName.values[monitorIndex].toString(),
    );

    final monitorResetIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics.concentric(
        color: Colors.grey[600]!,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
        concentricCenterColor: mainMonitorColor,
        concentricCenterDiameter: 4,
      ),
      name: EventsTraceName.monitorReset.toString(),
    );
    assert(monitorResetIndex == EventsTraceName.monitorReset.index);
    assert(
      trace(monitorResetIndex).name ==
          EventsTraceName.values[monitorResetIndex].toString(),
    );

    // VM GC
    final gcIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.blue,
        symbol: ChartSymbol.disc,
        diameter: 4,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: EventsTraceName.gc.toString(),
    );
    assert(gcIndex == EventsTraceName.gc.index);
    assert(
      trace(gcIndex).name == EventsTraceName.values[gcIndex].toString(),
    );

    assert(traces.length == EventsTraceName.values.length);
  }

  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (paused.value) return;

    addTimestamp(sample.timestamp);

    if (sample.isGC) {
      // Plot the VM GC on the VmEvent trace with a fixed Y coordinate.
      addDataToTrace(
        EventsTraceName.gc.index,
        chart_trace.Data(sample.timestamp, visibleVmEvent),
      );
    }
    final events = sample.memoryEventInfo;
    if (events.hasExtensionEvents) {
      final data = chart_trace.DataAggregate(
        sample.timestamp,
        extensionEvent,
        (events.extensionEvents?.theEvents ?? []).length,
      );
      addDataToTrace(EventsTraceName.extensionEvents.index, data);
    }

    // User events snapshot, auto-snapshot, manual GC, are plotted on the top-line
    // of the event pane (visible Events).
    final data = chart_trace.Data(
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
      final data = chart_trace.Data(
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
}
