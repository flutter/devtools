// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../charts/chart.dart';
import '../../charts/chart_controller.dart';
import '../../charts/chart_trace.dart' as trace;
import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/theme.dart';
import 'memory_controller.dart';
import 'memory_timeline.dart';

class VMChartController extends ChartController {
  VMChartController(this._memoryController)
      : super(
          displayTopLine: false,
          name: 'VM Memory',
        );

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
      TraceName.external.index,
      trace.Data(timestamp, externalValue),
    );

    final usedValue = sample.used.toDouble();
    addDataToTrace(TraceName.used.index, trace.Data(timestamp, usedValue));

    final capacityValue = sample.capacity.toDouble();
    addDataToTrace(
      TraceName.capacity.index,
      trace.Data(timestamp, capacityValue),
    );

    final rssValue = sample.rss.toDouble();
    addDataToTrace(TraceName.rSS.index, trace.Data(timestamp, rssValue));

    final rasterLayerValue = sample.rasterCache.layerBytes.toDouble();
    addDataToTrace(
      TraceName.rasterLayer.index,
      trace.Data(timestamp, rasterLayerValue),
    );

    final rasterPictureValue = sample.rasterCache.pictureBytes.toDouble();
    addDataToTrace(
      TraceName.rasterPicture.index,
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
enum TraceName {
  external,
  used,
  capacity,
  rSS,
  rasterLayer,
  rasterPicture,
}

class MemoryVMChartState extends State<MemoryVMChart> with AutoDisposeMixin {
  bool _initialized = false;

  /// Controller attached to the chart.
  VMChartController get _chartController => widget.chartController;

  /// Controller for managing memory collection.
  late MemoryController _memoryController;

  MemoryTimeline get _memoryTimeline => _memoryController.memoryTimeline;

  @override
  void initState() {
    super.initState();

    setupTraces();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);

    if (_initialized && _memoryController == newController) return;
    _memoryController = newController;
    _initialized = true;

    cancelListeners();

    setupTraces();
    _chartController.setupData();

    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      if (_memoryTimeline.sampleAddedNotifier.value != null)
        setState(() {
          _processHeapSample(_memoryTimeline.sampleAddedNotifier.value!);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController.timestamps.isNotEmpty) {
      return Container(
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
      assert(_chartController.traces.length == TraceName.values.length);

      final externalIndex = TraceName.external.index;
      assert(_chartController.trace(externalIndex).name ==
          TraceName.values[externalIndex].toString());

      final usedIndex = TraceName.used.index;
      assert(_chartController.trace(usedIndex).name ==
          TraceName.values[usedIndex].toString());

      final capacityIndex = TraceName.capacity.index;
      assert(_chartController.trace(capacityIndex).name ==
          TraceName.values[capacityIndex].toString());

      final rSSIndex = TraceName.rSS.index;
      assert(_chartController.trace(rSSIndex).name ==
          TraceName.values[rSSIndex].toString());

      final rasterLayerIndex = TraceName.rasterLayer.index;
      assert(_chartController.trace(rasterLayerIndex).name ==
          TraceName.values[rasterLayerIndex].toString());

      final rasterPictureIndex = TraceName.rasterPicture.index;
      assert(_chartController.trace(rasterPictureIndex).name ==
          TraceName.values[rasterPictureIndex].toString());

      return;
    }

    final externalIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: externalColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.external.toString(),
    );
    assert(externalIndex == TraceName.external.index);
    assert(_chartController.trace(externalIndex).name ==
        TraceName.values[externalIndex].toString());

    // Used Heap
    final usedIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: usedColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.used.toString(),
    );
    assert(usedIndex == TraceName.used.index);
    assert(_chartController.trace(usedIndex).name ==
        TraceName.values[usedIndex].toString());

    // Heap Capacity
    final capacityIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: capacityColor,
        diameter: 0.0,
        symbol: trace.ChartSymbol.dashedLine,
      ),
      name: TraceName.capacity.toString(),
    );
    assert(capacityIndex == TraceName.capacity.index);
    assert(_chartController.trace(capacityIndex).name ==
        TraceName.values[capacityIndex].toString());

    // RSS
    final rSSIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: rssColor,
        symbol: trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: TraceName.rSS.toString(),
    );
    assert(rSSIndex == TraceName.rSS.index);
    assert(_chartController.trace(rSSIndex).name ==
        TraceName.values[rSSIndex].toString());

    final rasterLayerIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: rasterLayerColor,
        symbol: trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: TraceName.rasterLayer.toString(),
    );
    assert(rasterLayerIndex == TraceName.rasterLayer.index);
    assert(_chartController.trace(rasterLayerIndex).name ==
        TraceName.values[rasterLayerIndex].toString());

    final rasterPictureIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: rasterPictureColor,
        symbol: trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: TraceName.rasterPicture.toString(),
    );
    assert(rasterPictureIndex == TraceName.rasterPicture.index);
    assert(_chartController.trace(rasterPictureIndex).name ==
        TraceName.values[rasterPictureIndex].toString());

    assert(_chartController.traces.length == TraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.paused.value) return;
    _chartController.addSample(sample);
  }
}
