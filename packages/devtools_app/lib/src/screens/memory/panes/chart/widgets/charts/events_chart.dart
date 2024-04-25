// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/charts/chart.dart';
import '../../../../../../shared/charts/chart_trace.dart' as trace;
import '../../../../../../shared/charts/chart_trace.dart' show ChartType;
import '../../../../shared/primitives/memory_timeline.dart';
import '../../controller/event_chart_controller.dart';

/// Events trace name displayed
const manualSnapshotLegendName = 'Snapshot';
const autoSnapshotLegendName = 'Auto';
const monitorLegendName = 'Monitor';
const resetLegendName = 'Reset';
const vmGCLegendName = 'GC VM';
const manualGCLegendName = 'Manual';
const eventLegendName = 'Event';
const eventsLegendName = 'Events';

class MemoryEventsPane extends StatefulWidget {
  const MemoryEventsPane(this.chart, {super.key});

  final EventChartController chart;

  @override
  MemoryEventsPaneState createState() => MemoryEventsPaneState();
}

class MemoryEventsPaneState extends State<MemoryEventsPane>
    with AutoDisposeMixin {
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

  MemoryTimeline get _memoryTimeline => widget.chart.memoryTimeline;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeData = Theme.of(context);
    setupTraces(isDarkMode: themeData.isDarkTheme);
  }

  @override
  void didUpdateWidget(covariant MemoryEventsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart == widget.chart) return;
    _init();
  }

  void _init() {
    // Line chart fixed Y range.
    widget.chart.setFixedYRange(visibleVmEvent, extensionEvent);

    cancelListeners();

    widget.chart.setupData();

    // Monitor heap samples.
    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      final value = _memoryTimeline.sampleAddedNotifier.value;
      if (value == null) return;
      setState(() => _processHeapSample(value));
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
    if (widget.chart.timestamps.isNotEmpty) {
      return Chart(widget.chart);
    }

    return const SizedBox(width: denseSpacing);
  }

  void setupTraces({bool isDarkMode = true}) {
    if (widget.chart.traces.isNotEmpty) {
      assert(widget.chart.traces.length == EventsTraceName.values.length);

      final extensionEventsIndex = EventsTraceName.extensionEvents.index;
      assert(
        widget.chart.trace(extensionEventsIndex).name ==
            EventsTraceName.values[extensionEventsIndex].toString(),
      );

      final snapshotIndex = EventsTraceName.snapshot.index;
      assert(
        widget.chart.trace(snapshotIndex).name ==
            EventsTraceName.values[snapshotIndex].toString(),
      );

      final autoSnapshotIndex = EventsTraceName.autoSnapshot.index;
      assert(
        widget.chart.trace(autoSnapshotIndex).name ==
            EventsTraceName.values[autoSnapshotIndex].toString(),
      );

      final manualGCIndex = EventsTraceName.manualGC.index;
      assert(
        widget.chart.trace(manualGCIndex).name ==
            EventsTraceName.values[manualGCIndex].toString(),
      );

      final monitorIndex = EventsTraceName.monitor.index;
      assert(
        widget.chart.trace(monitorIndex).name ==
            EventsTraceName.values[monitorIndex].toString(),
      );

      final monitorResetIndex = EventsTraceName.monitorReset.index;
      assert(
        widget.chart.trace(monitorResetIndex).name ==
            EventsTraceName.values[monitorResetIndex].toString(),
      );

      final gcIndex = EventsTraceName.gc.index;
      assert(
        widget.chart.trace(gcIndex).name ==
            EventsTraceName.values[gcIndex].toString(),
      );

      return;
    }

    final extensionEventsIndex = widget.chart.createTrace(
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
      name: EventsTraceName.extensionEvents.toString(),
    );
    assert(extensionEventsIndex == EventsTraceName.extensionEvents.index);
    assert(
      widget.chart.trace(extensionEventsIndex).name ==
          EventsTraceName.values[extensionEventsIndex].toString(),
    );

    final snapshotIndex = widget.chart.createTrace(
      trace.ChartType.symbol,
      trace.PaintCharacteristics(
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
      widget.chart.trace(snapshotIndex).name ==
          EventsTraceName.values[snapshotIndex].toString(),
    );

    // Auto-snapshot
    final autoSnapshotIndex = widget.chart.createTrace(
      ChartType.symbol,
      trace.PaintCharacteristics(
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
      widget.chart.trace(autoSnapshotIndex).name ==
          EventsTraceName.values[autoSnapshotIndex].toString(),
    );

    // Manual GC
    final manualGCIndex = widget.chart.createTrace(
      ChartType.symbol,
      trace.PaintCharacteristics(
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
      widget.chart.trace(manualGCIndex).name ==
          EventsTraceName.values[manualGCIndex].toString(),
    );

    final mainMonitorColor =
        isDarkMode ? Colors.yellowAccent : Colors.yellowAccent.shade400;

    // Monitor
    final monitorIndex = widget.chart.createTrace(
      ChartType.symbol,
      trace.PaintCharacteristics(
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
      widget.chart.trace(monitorIndex).name ==
          EventsTraceName.values[monitorIndex].toString(),
    );

    final monitorResetIndex = widget.chart.createTrace(
      ChartType.symbol,
      trace.PaintCharacteristics.concentric(
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
      widget.chart.trace(monitorResetIndex).name ==
          EventsTraceName.values[monitorResetIndex].toString(),
    );

    // VM GC
    final gcIndex = widget.chart.createTrace(
      ChartType.symbol,
      trace.PaintCharacteristics(
        color: Colors.blue,
        symbol: trace.ChartSymbol.disc,
        diameter: 4,
        fixedMinY: visibleVmEvent,
        fixedMaxY: extensionEvent,
      ),
      name: EventsTraceName.gc.toString(),
    );
    assert(gcIndex == EventsTraceName.gc.index);
    assert(
      widget.chart.trace(gcIndex).name ==
          EventsTraceName.values[gcIndex].toString(),
    );

    assert(widget.chart.traces.length == EventsTraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (widget.chart.paused.value) return;
    widget.chart.addSample(sample);
  }
}
