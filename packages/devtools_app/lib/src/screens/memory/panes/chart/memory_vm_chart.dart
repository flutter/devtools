// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../shared/charts/chart.dart';
import '../../../../shared/charts/chart_controller.dart';
import '../../../../shared/charts/chart_trace.dart' as trace;
import '../../../../shared/charts/chart_trace.dart' show ChartType, ChartSymbol;
import '../../../../shared/utils.dart';
import '../../framework/connected/memory_controller.dart';
import '../../shared/primitives/memory_timeline.dart';

class VMChartController extends ChartController {
  VMChartController(this._memoryController) : super(name: 'VM Memory');

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
    if (_memoryController.isPaused) return;

    addTimestamp(sample.timestamp);

    final timestamp = sample.timestamp;
    final externalValue = sample.external.toDouble();
    addDataToTrace(
      VmTraceName.external.index,
      trace.Data(timestamp, externalValue),
    );

    final usedValue = sample.used.toDouble();
    addDataToTrace(VmTraceName.used.index, trace.Data(timestamp, usedValue));

    final capacityValue = sample.capacity.toDouble();
    addDataToTrace(
      VmTraceName.capacity.index,
      trace.Data(timestamp, capacityValue),
    );

    final rssValue = sample.rss.toDouble();
    addDataToTrace(VmTraceName.rSS.index, trace.Data(timestamp, rssValue));

    final rasterLayerValue = sample.rasterCache.layerBytes.toDouble();
    addDataToTrace(
      VmTraceName.rasterLayer.index,
      trace.Data(timestamp, rasterLayerValue),
    );

    final rasterPictureValue = sample.rasterCache.pictureBytes.toDouble();
    addDataToTrace(
      VmTraceName.rasterPicture.index,
      trace.Data(timestamp, rasterPictureValue),
    );
  }

  void addDataToTrace(int traceIndex, trace.Data data) {
    this.trace(traceIndex).addDatum(data);
  }
}

class MemoryVMChart extends StatefulWidget {
  const MemoryVMChart(this.chartController, {Key? key}) : super(key: key);

  final VMChartController chartController;

  @override
  MemoryVMChartState createState() => MemoryVMChartState();
}

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum VmTraceName {
  external,
  used,
  capacity,
  rSS,
  rasterLayer,
  rasterPicture,
}

class MemoryVMChartState extends State<MemoryVMChart>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryVMChart> {
  /// Controller attached to the chart.
  VMChartController get _chartController => widget.chartController;

  MemoryTimeline get _memoryTimeline => controller.memoryTimeline;

  @override
  void initState() {
    super.initState();

    setupTraces();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

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
    if (controller.paused.value) return;
    _chartController.addSample(sample);
  }
}
