// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/charts/chart.dart';
import '../../../../../shared/charts/chart_trace.dart' as trace;
import '../../../../../shared/charts/chart_trace.dart' show ChartType;
import '../../../../../shared/utils.dart';
import '../../../framework/connected/memory_controller.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../controller/event_chart_controller.dart';

// TODO(terry): Consider custom painter?
const _base = 'assets/img/legend/';
const snapshotManualLegend = '${_base}snapshot_manual_glyph.png';
const snapshotAutoLegend = '${_base}snapshot_auto_glyph.png';
const monitorLegend = '${_base}monitor_glyph.png';
const resetDarkLegend = '${_base}reset_glyph_dark.png';
const resetLightLegend = '${_base}reset_glyph_light.png';
const gcManualLegend = '${_base}gc_manual_glyph.png';
const gcVMLegend = '${_base}gc_vm_glyph.png';
String eventLegendAsset(int eventCount) =>
    '$_base${pluralize('event', eventCount)}_glyph.png';

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
  const MemoryEventsPane(this.chartController, {Key? key}) : super(key: key);

  final EventChartController chartController;

  @override
  MemoryEventsPaneState createState() => MemoryEventsPaneState();
}

class MemoryEventsPaneState extends State<MemoryEventsPane>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryEventsPane> {
  /// Controller attached to this chart.
  EventChartController get _chartController => widget.chartController;

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

  MemoryTimeline get _memoryTimeline =>
      controller.controllers.chart.memoryTimeline;

  @override
  void initState() {
    super.initState();

    // Line chart fixed Y range.
    _chartController.setFixedYRange(visibleVmEvent, extensionEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    final themeData = Theme.of(context);

    cancelListeners();

    setupTraces(isDarkMode: themeData.isDarkTheme);
    _chartController.setupData();

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
    if (_chartController.timestamps.isNotEmpty) {
      return Chart(_chartController);
    }

    return const SizedBox(width: denseSpacing);
  }

  void setupTraces({bool isDarkMode = true}) {
    if (_chartController.traces.isNotEmpty) {
      assert(_chartController.traces.length == EventsTraceName.values.length);

      final extensionEventsIndex = EventsTraceName.extensionEvents.index;
      assert(
        _chartController.trace(extensionEventsIndex).name ==
            EventsTraceName.values[extensionEventsIndex].toString(),
      );

      final snapshotIndex = EventsTraceName.snapshot.index;
      assert(
        _chartController.trace(snapshotIndex).name ==
            EventsTraceName.values[snapshotIndex].toString(),
      );

      final autoSnapshotIndex = EventsTraceName.autoSnapshot.index;
      assert(
        _chartController.trace(autoSnapshotIndex).name ==
            EventsTraceName.values[autoSnapshotIndex].toString(),
      );

      final manualGCIndex = EventsTraceName.manualGC.index;
      assert(
        _chartController.trace(manualGCIndex).name ==
            EventsTraceName.values[manualGCIndex].toString(),
      );

      final monitorIndex = EventsTraceName.monitor.index;
      assert(
        _chartController.trace(monitorIndex).name ==
            EventsTraceName.values[monitorIndex].toString(),
      );

      final monitorResetIndex = EventsTraceName.monitorReset.index;
      assert(
        _chartController.trace(monitorResetIndex).name ==
            EventsTraceName.values[monitorResetIndex].toString(),
      );

      final gcIndex = EventsTraceName.gc.index;
      assert(
        _chartController.trace(gcIndex).name ==
            EventsTraceName.values[gcIndex].toString(),
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
      name: EventsTraceName.extensionEvents.toString(),
    );
    assert(extensionEventsIndex == EventsTraceName.extensionEvents.index);
    assert(
      _chartController.trace(extensionEventsIndex).name ==
          EventsTraceName.values[extensionEventsIndex].toString(),
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
      name: EventsTraceName.snapshot.toString(),
    );
    assert(snapshotIndex == EventsTraceName.snapshot.index);
    assert(
      _chartController.trace(snapshotIndex).name ==
          EventsTraceName.values[snapshotIndex].toString(),
    );

    // Auto-snapshot
    final autoSnapshotIndex = _chartController.createTrace(
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
      _chartController.trace(autoSnapshotIndex).name ==
          EventsTraceName.values[autoSnapshotIndex].toString(),
    );

    // Manual GC
    final manualGCIndex = _chartController.createTrace(
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
      _chartController.trace(manualGCIndex).name ==
          EventsTraceName.values[manualGCIndex].toString(),
    );

    final mainMonitorColor =
        isDarkMode ? Colors.yellowAccent : Colors.yellowAccent.shade400;

    // Monitor
    final monitorIndex = _chartController.createTrace(
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
      _chartController.trace(monitorIndex).name ==
          EventsTraceName.values[monitorIndex].toString(),
    );

    final monitorResetIndex = _chartController.createTrace(
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
      _chartController.trace(monitorResetIndex).name ==
          EventsTraceName.values[monitorResetIndex].toString(),
    );

    // VM GC
    final gcIndex = _chartController.createTrace(
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
      _chartController.trace(gcIndex).name ==
          EventsTraceName.values[gcIndex].toString(),
    );

    assert(_chartController.traces.length == EventsTraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (controller.controllers.chart.isPaused) return;
    _chartController.addSample(sample);
  }
}
