// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/charts/chart.dart';
import '../../../../shared/primitives/memory_timeline.dart';
import '../../controller/charts/event_chart_controller.dart';

class MemoryEventsPane extends StatefulWidget {
  const MemoryEventsPane(this.chart, {super.key});

  final EventChartController chart;

  @override
  MemoryEventsPaneState createState() => MemoryEventsPaneState();
}

class MemoryEventsPaneState extends State<MemoryEventsPane>
    with AutoDisposeMixin {
  MemoryTimeline get _memoryTimeline => widget.chart.memoryTimeline;

  @override
  void initState() {
    super.initState();
    _init();
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
    addAutoDisposeListener(_memoryTimeline.sampleAdded, () {
      final value = _memoryTimeline.sampleAdded.value;
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

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (widget.chart.paused.value) return;
    widget.chart.addSample(sample);
  }
}
