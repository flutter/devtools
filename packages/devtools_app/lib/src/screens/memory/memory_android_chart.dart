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

class AndroidChartController extends ChartController {
  AndroidChartController(this._memoryController, {sharedLabels = const <int>[]})
      : super(
          displayTopLine: false,
          name: 'Android',
          sharedLabelimestamps: sharedLabels,
        );

  final MemoryController _memoryController;

  // TODO(terry): Only load max visible data collected, when pruning of data
  //              charted is added.
  /// Preload any existing data collected but not in the chart.
  @override
  void setupData() {
    // Only display if traces have been created. Android memory may not
    // have been toggled to be displayed - yet.
    if (traces.isNotEmpty) {
      final chartDataLength = timestampsLength;
      final dataLength = _memoryController.memoryTimeline.data.length;

      final dataRange = _memoryController.memoryTimeline.data.getRange(
        chartDataLength,
        dataLength,
      );

      dataRange.forEach(addSample);
    }
  }

  /// Loads all heap samples (live data or offline).
  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.isPaused) return;

    addTimestamp(sample.timestamp);

    final timestamp = sample.timestamp;
    final adb = sample.adbMemoryInfo;

    final stackValue = adb.stack.toDouble();
    addDataToTrace(TraceName.stack.index, trace.Data(timestamp, stackValue));

    final graphicValue = adb.graphics.toDouble();
    addDataToTrace(
      TraceName.graphics.index,
      trace.Data(
        timestamp,
        graphicValue,
      ),
    );

    final nativeHeapValue = adb.nativeHeap.toDouble();
    addDataToTrace(
      TraceName.nativeHeap.index,
      trace.Data(
        timestamp,
        nativeHeapValue,
      ),
    );

    final javaHeapValue = adb.javaHeap.toDouble();
    addDataToTrace(
      TraceName.javaHeap.index,
      trace.Data(timestamp, javaHeapValue),
    );

    final codeValue = adb.code.toDouble();
    addDataToTrace(TraceName.code.index, trace.Data(timestamp, codeValue));

    final otherValue = adb.other.toDouble();
    addDataToTrace(TraceName.other.index, trace.Data(timestamp, otherValue));

    final systemValue = adb.system.toDouble();
    addDataToTrace(TraceName.system.index, trace.Data(timestamp, systemValue));

    final totalValue = adb.total.toDouble();
    addDataToTrace(TraceName.total.index, trace.Data(timestamp, totalValue));
  }

  void addDataToTrace(int traceIndex, trace.Data data) {
    this.trace(traceIndex).addDatum(data);
  }
}

class MemoryAndroidChart extends StatefulWidget {
  const MemoryAndroidChart(this.chartController, {Key? key}) : super(key: key);

  final AndroidChartController chartController;

  @override
  MemoryAndroidChartState createState() => MemoryAndroidChartState();
}

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum TraceName {
  stack,
  javaHeap,
  code,
  graphics,
  nativeHeap,
  other,
  system,
  total,
}

class MemoryAndroidChartState extends State<MemoryAndroidChart>
    with AutoDisposeMixin {
  /// Controller attached to the chart.
  AndroidChartController get _chartController => widget.chartController;

  bool _initialized = false;

  /// Controller for managing memory collection.
  late MemoryController _memoryController;

  MemoryTimeline get _memoryTimeline => _memoryController.memoryTimeline;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newMemoryController = Provider.of<MemoryController>(context);
    if (_initialized && _memoryController == newMemoryController) return;
    _memoryController = newMemoryController;
    _initialized = true;

    cancelListeners();

    setupTraces();
    _chartController.setupData();

    if (_memoryTimeline.sampleAddedNotifier.value != null) {
      addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
        _processHeapSample(_memoryTimeline.sampleAddedNotifier.value!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController.timestamps.isNotEmpty) {
      return Container(
        Chart(_chartController),
        height: defaultChartHeight,
      );
    }

    return const SizedBox(width: denseSpacing);
  }

  /// TODO(terry): Colors used in charts (move to theme).
  static const otherColor = Color(0xffff8800); // HoloOrangeDark;
  static const nativeHeapColor = Color(0xff33b5e5); // HoloBlueLight
  final graphicColor = Colors.greenAccent.shade400;
  static const codeColor = Color(0xffaa66cc); // HoloPurple
  static const javaColor = Colors.yellow;
  static const stackColor = Colors.tealAccent;
  static const systemColor = Color(0xff669900); // HoloGreenDark
  final totalColor = Colors.blueGrey.shade100;

  void setupTraces() {
    if (_chartController.traces.isNotEmpty) {
      assert(_chartController.traces.length == TraceName.values.length);

      final stackIndex = TraceName.stack.index;
      assert(
        _chartController.trace(stackIndex).name ==
            TraceName.values[stackIndex].toString(),
      );

      final graphicsIndex = TraceName.graphics.index;
      assert(
        _chartController.trace(graphicsIndex).name ==
            TraceName.values[graphicsIndex].toString(),
      );

      final nativeHeapIndex = TraceName.nativeHeap.index;
      assert(
        _chartController.trace(nativeHeapIndex).name ==
            TraceName.values[nativeHeapIndex].toString(),
      );

      final javaHeapIndex = TraceName.javaHeap.index;
      assert(
        _chartController.trace(javaHeapIndex).name ==
            TraceName.values[javaHeapIndex].toString(),
      );

      final codeIndex = TraceName.code.index;
      assert(
        _chartController.trace(codeIndex).name ==
            TraceName.values[codeIndex].toString(),
      );

      final otherIndex = TraceName.other.index;
      assert(
        _chartController.trace(otherIndex).name ==
            TraceName.values[otherIndex].toString(),
      );

      final systemIndex = TraceName.system.index;
      assert(
        _chartController.trace(systemIndex).name ==
            TraceName.values[systemIndex].toString(),
      );

      final totalIndex = TraceName.total.index;
      assert(
        _chartController.trace(totalIndex).name ==
            TraceName.values[totalIndex].toString(),
      );

      return;
    }

    // Need to create the trace first time.

    // Stack trace
    final stackIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: stackColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.stack.toString(),
    );
    assert(stackIndex == TraceName.stack.index);
    assert(
      _chartController.trace(stackIndex).name ==
          TraceName.values[stackIndex].toString(),
    );

    // Java heap trace.
    final javaHeapIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: javaColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.javaHeap.toString(),
    );
    assert(javaHeapIndex == TraceName.javaHeap.index);
    assert(
      _chartController.trace(javaHeapIndex).name ==
          TraceName.values[javaHeapIndex].toString(),
    );

    // Code trace
    final codeIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: codeColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.code.toString(),
    );
    assert(codeIndex == TraceName.code.index);
    assert(
      _chartController.trace(codeIndex).name ==
          TraceName.values[codeIndex].toString(),
    );

    // Graphics Trace
    final graphicIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: graphicColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.graphics.toString(),
    );
    assert(graphicIndex == TraceName.graphics.index);
    assert(
      _chartController.trace(graphicIndex).name ==
          TraceName.values[graphicIndex].toString(),
    );

    // Native heap trace.
    final nativeHeapIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: nativeHeapColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.nativeHeap.toString(),
    );
    assert(nativeHeapIndex == TraceName.nativeHeap.index);
    assert(
      _chartController.trace(nativeHeapIndex).name ==
          TraceName.values[nativeHeapIndex].toString(),
    );

    // Other trace
    final otherIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: otherColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.other.toString(),
    );
    assert(otherIndex == TraceName.other.index);
    assert(
      _chartController.trace(otherIndex).name ==
          TraceName.values[otherIndex].toString(),
    );

    // System trace
    final systemIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: systemColor,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: TraceName.system.toString(),
    );
    assert(systemIndex == TraceName.system.index);
    assert(
      _chartController.trace(systemIndex).name ==
          TraceName.values[systemIndex].toString(),
    );

    // Total trace.
    final totalIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: totalColor,
        symbol: trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: TraceName.total.toString(),
    );
    assert(totalIndex == TraceName.total.index);
    assert(
      _chartController.trace(totalIndex).name ==
          TraceName.values[totalIndex].toString(),
    );

    assert(_chartController.traces.length == TraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.paused.value) return;
    _chartController.addSample(sample);
  }
}
