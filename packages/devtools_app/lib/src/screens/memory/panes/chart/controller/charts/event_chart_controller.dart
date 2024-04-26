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

class _Sizes {
  /// VM's GCs are displayed in a smaller glyph and closer to the heap graph.
  static const visibleVm = 0.4;

  /// Flutter events and user custom events.
  static const extensions = 3.7;

  /// Event to display in the event pane (User initiated GC, snapshot,
  /// automatic snapshot, etc.)
  static const visible = 2.4;

  /// Monitor events Y axis.
  static const visibleMonitor = 1.4;
}

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum _EventsTraceName {
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
    setFixedYRange(_Sizes.visibleVm, _Sizes.extensions);
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
      assert(traces.length == _EventsTraceName.values.length);

      final extensionEventsIndex = _EventsTraceName.extensionEvents.index;
      assert(
        trace(extensionEventsIndex).name ==
            _EventsTraceName.values[extensionEventsIndex].toString(),
      );

      final snapshotIndex = _EventsTraceName.snapshot.index;
      assert(
        trace(snapshotIndex).name ==
            _EventsTraceName.values[snapshotIndex].toString(),
      );

      final autoSnapshotIndex = _EventsTraceName.autoSnapshot.index;
      assert(
        trace(autoSnapshotIndex).name ==
            _EventsTraceName.values[autoSnapshotIndex].toString(),
      );

      final manualGCIndex = _EventsTraceName.manualGC.index;
      assert(
        trace(manualGCIndex).name ==
            _EventsTraceName.values[manualGCIndex].toString(),
      );

      final monitorIndex = _EventsTraceName.monitor.index;
      assert(
        trace(monitorIndex).name ==
            _EventsTraceName.values[monitorIndex].toString(),
      );

      final monitorResetIndex = _EventsTraceName.monitorReset.index;
      assert(
        trace(monitorResetIndex).name ==
            _EventsTraceName.values[monitorResetIndex].toString(),
      );

      final gcIndex = _EventsTraceName.gc.index;
      assert(
        trace(gcIndex).name == _EventsTraceName.values[gcIndex].toString(),
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
        fixedMinY: _Sizes.visibleVm,
        fixedMaxY: _Sizes.extensions,
      ),
      name: _EventsTraceName.extensionEvents.toString(),
    );
    assert(extensionEventsIndex == _EventsTraceName.extensionEvents.index);
    assert(
      trace(extensionEventsIndex).name ==
          _EventsTraceName.values[extensionEventsIndex].toString(),
    );

    final snapshotIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.green,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: _Sizes.visibleVm,
        fixedMaxY: _Sizes.extensions,
      ),
      name: _EventsTraceName.snapshot.toString(),
    );
    assert(snapshotIndex == _EventsTraceName.snapshot.index);
    assert(
      trace(snapshotIndex).name ==
          _EventsTraceName.values[snapshotIndex].toString(),
    );

    // Auto-snapshot
    final autoSnapshotIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.red,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: _Sizes.visibleVm,
        fixedMaxY: _Sizes.extensions,
      ),
      name: _EventsTraceName.autoSnapshot.toString(),
    );
    assert(autoSnapshotIndex == _EventsTraceName.autoSnapshot.index);
    assert(
      trace(autoSnapshotIndex).name ==
          _EventsTraceName.values[autoSnapshotIndex].toString(),
    );

    // Manual GC
    final manualGCIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.blue,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: _Sizes.visibleVm,
        fixedMaxY: _Sizes.extensions,
      ),
      name: _EventsTraceName.manualGC.toString(),
    );
    assert(manualGCIndex == _EventsTraceName.manualGC.index);
    assert(
      trace(manualGCIndex).name ==
          _EventsTraceName.values[manualGCIndex].toString(),
    );

    final mainMonitorColor = Colors.yellowAccent.shade400;

    // Monitor
    final monitorIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: mainMonitorColor,
        strokeWidth: 3,
        diameter: 6,
        fixedMinY: _Sizes.visibleVm,
        fixedMaxY: _Sizes.extensions,
      ),
      name: _EventsTraceName.monitor.toString(),
    );
    assert(monitorIndex == _EventsTraceName.monitor.index);
    assert(
      trace(monitorIndex).name ==
          _EventsTraceName.values[monitorIndex].toString(),
    );

    final monitorResetIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics.concentric(
        color: Colors.grey[600]!,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: _Sizes.visibleVm,
        fixedMaxY: _Sizes.extensions,
        concentricCenterColor: mainMonitorColor,
        concentricCenterDiameter: 4,
      ),
      name: _EventsTraceName.monitorReset.toString(),
    );
    assert(monitorResetIndex == _EventsTraceName.monitorReset.index);
    assert(
      trace(monitorResetIndex).name ==
          _EventsTraceName.values[monitorResetIndex].toString(),
    );

    // VM GC
    final gcIndex = createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.blue,
        symbol: ChartSymbol.disc,
        diameter: 4,
        fixedMinY: _Sizes.visibleVm,
        fixedMaxY: _Sizes.extensions,
      ),
      name: _EventsTraceName.gc.toString(),
    );
    assert(gcIndex == _EventsTraceName.gc.index);
    assert(
      trace(gcIndex).name == _EventsTraceName.values[gcIndex].toString(),
    );

    assert(traces.length == _EventsTraceName.values.length);
  }

  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (paused.value) return;

    addTimestamp(sample.timestamp);

    if (sample.isGC) {
      // Plot the VM GC on the VmEvent trace with a fixed Y coordinate.
      addDataToTrace(
        _EventsTraceName.gc.index,
        chart_trace.Data(sample.timestamp, _Sizes.visibleVm),
      );
    }
    final events = sample.memoryEventInfo;
    if (events.hasExtensionEvents) {
      final data = chart_trace.DataAggregate(
        sample.timestamp,
        _Sizes.extensions,
        (events.extensionEvents?.theEvents ?? []).length,
      );
      addDataToTrace(_EventsTraceName.extensionEvents.index, data);
    }

    // User events snapshot, auto-snapshot, manual GC, are plotted on the top-line
    // of the event pane (visible Events).
    final data = chart_trace.Data(
      sample.timestamp,
      _Sizes.visible,
    );

    if (events.isEventGC) {
      // Plot manual requested GC on the visibleEvent Y coordinate.
      addDataToTrace(_EventsTraceName.manualGC.index, data);
    }

    if (events.isEventSnapshot) {
      // Plot snapshot on the visibleEvent Y coordinate.
      addDataToTrace(_EventsTraceName.snapshot.index, data);
    }

    if (events.isEventSnapshotAuto) {
      // Plot auto-snapshot on the visibleEvent Y coordinate.
      addDataToTrace(_EventsTraceName.autoSnapshot.index, data);
    }

    if (sample.memoryEventInfo.isEventAllocationAccumulator) {
      final allocationEvent = events.allocationAccumulator!;
      final data = chart_trace.Data(
        sample.timestamp,
        _Sizes.visibleMonitor,
      );
      if (allocationEvent.isReset) {
        addDataToTrace(_EventsTraceName.monitorReset.index, data);
      } else if (allocationEvent.isStart) {
        addDataToTrace(_EventsTraceName.monitor.index, data);
      }
    }
  }
}
