// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/charts/chart.dart';
import '../../../../../shared/charts/chart_controller.dart';

class MemoryChart extends StatefulWidget {
  const MemoryChart(this.chart, this.sampleAdded, {super.key});

  final ChartController chart;
  final ValueListenable<HeapSample?> sampleAdded;

  @override
  MemoryChartState createState() => MemoryChartState();
}

class MemoryChartState extends State<MemoryChart> with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    cancelListeners();
    addAutoDisposeListener(widget.sampleAdded);
  }

  @override
  void didUpdateWidget(covariant MemoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart == widget.chart) return;
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultChartHeight,
      child: Chart(widget.chart),
    );
  }
}
