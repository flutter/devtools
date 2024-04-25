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
    cancelListeners();

    // Monitor heap samples.
    addAutoDisposeListener(_memoryTimeline.sampleAdded, () {
      final value = _memoryTimeline.sampleAdded.value;
      if (value == null) return;
      setState(() => widget.chart.addSample(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chart.timestamps.isNotEmpty) {
      return Chart(widget.chart);
    }

    return const SizedBox(width: denseSpacing);
  }
}
