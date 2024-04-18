// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/charts/chart.dart';
import '../../../../../shared/charts/chart_trace.dart' as trace;
import '../../../../../shared/charts/chart_trace.dart'
    show ChartType, ChartSymbol;
import '../../../shared/primitives/memory_timeline.dart';
import '../controller/vm_chart_controller.dart';
import '../data/charts.dart';

class MemoryVMChart extends StatefulWidget {
  const MemoryVMChart(this.chart, {Key? key}) : super(key: key);

  final VMChartController chart;

  @override
  MemoryVMChartState createState() => MemoryVMChartState();
}

class MemoryVMChartState extends State<MemoryVMChart> with AutoDisposeMixin {
  /// Controller attached to the chart.
  VMChartController get _chartController => widget.chart;

  MemoryTimeline get _memoryTimeline => widget.chart.memoryTimeline;

  @override
  void initState() {
    super.initState();

    _init();
  }

  void _init() {
    cancelListeners();

    setupTraces();
    _chartController.setupData();

    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      if (_memoryTimeline.sampleAddedNotifier.value != null) {
        setState(() {
          _processHeapSample(_memoryTimeline.sampleAddedNotifier.value!);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant MemoryVMChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart == widget.chart) return;
    _init();
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController.timestamps.isNotEmpty) {
      return SizedBox(
        height: defaultChartHeight,
        child: Chart(_chartController),
      );
    }

    return const SizedBox(width: denseSpacing);
  }

  // TODO(terry): Move colors to theme?
  static final capacityColor = Colors.grey[400]!;
  static const usedColor = Color(0xff33b5e5);
  static const externalColor = Color(0xff4ddeff);
  // TODO(terry): UX review of raster colors see https://github.com/flutter/devtools/issues/2616
  final rasterLayerColor = Colors.greenAccent.shade400;
  static const rasterPictureColor = Color(0xffff4444);
  final rssColor = Colors.orange.shade700;

  void setupTraces() {
    if (_chartController.traces.isNotEmpty) {
      assert(_chartController.traces.length == VmTraceName.values.length);

      final externalIndex = VmTraceName.external.index;
      assert(
        _chartController.trace(externalIndex).name ==
            VmTraceName.values[externalIndex].toString(),
      );

      final usedIndex = VmTraceName.used.index;
      assert(
        _chartController.trace(usedIndex).name ==
            VmTraceName.values[usedIndex].toString(),
      );

      final capacityIndex = VmTraceName.capacity.index;
      assert(
        _chartController.trace(capacityIndex).name ==
            VmTraceName.values[capacityIndex].toString(),
      );

      final rSSIndex = VmTraceName.rSS.index;
      assert(
        _chartController.trace(rSSIndex).name ==
            VmTraceName.values[rSSIndex].toString(),
      );

      final rasterLayerIndex = VmTraceName.rasterLayer.index;
      assert(
        _chartController.trace(rasterLayerIndex).name ==
            VmTraceName.values[rasterLayerIndex].toString(),
      );

      final rasterPictureIndex = VmTraceName.rasterPicture.index;
      assert(
        _chartController.trace(rasterPictureIndex).name ==
            VmTraceName.values[rasterPictureIndex].toString(),
      );

      return;
    }

    final externalIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: externalColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: VmTraceName.external.toString(),
    );
    assert(externalIndex == VmTraceName.external.index);
    assert(
      _chartController.trace(externalIndex).name ==
          VmTraceName.values[externalIndex].toString(),
    );

    // Used Heap
    final usedIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: usedColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: VmTraceName.used.toString(),
    );
    assert(usedIndex == VmTraceName.used.index);
    assert(
      _chartController.trace(usedIndex).name ==
          VmTraceName.values[usedIndex].toString(),
    );

    // Heap Capacity
    final capacityIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: capacityColor,
        diameter: 0.0,
        symbol: ChartSymbol.dashedLine,
      ),
      name: VmTraceName.capacity.toString(),
    );
    assert(capacityIndex == VmTraceName.capacity.index);
    assert(
      _chartController.trace(capacityIndex).name ==
          VmTraceName.values[capacityIndex].toString(),
    );

    // RSS
    final rSSIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: rssColor,
        symbol: ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: VmTraceName.rSS.toString(),
    );
    assert(rSSIndex == VmTraceName.rSS.index);
    assert(
      _chartController.trace(rSSIndex).name ==
          VmTraceName.values[rSSIndex].toString(),
    );

    final rasterLayerIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: rasterLayerColor,
        symbol: trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: VmTraceName.rasterLayer.toString(),
    );
    assert(rasterLayerIndex == VmTraceName.rasterLayer.index);
    assert(
      _chartController.trace(rasterLayerIndex).name ==
          VmTraceName.values[rasterLayerIndex].toString(),
    );

    final rasterPictureIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: rasterPictureColor,
        symbol: trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: VmTraceName.rasterPicture.toString(),
    );
    assert(rasterPictureIndex == VmTraceName.rasterPicture.index);
    assert(
      _chartController.trace(rasterPictureIndex).name ==
          VmTraceName.values[rasterPictureIndex].toString(),
    );

    assert(_chartController.traces.length == VmTraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (widget.chart.paused.value) return;
    _chartController.addSample(sample);
  }
}
