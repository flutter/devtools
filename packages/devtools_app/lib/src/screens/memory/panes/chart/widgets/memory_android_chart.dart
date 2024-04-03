// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/charts/chart.dart';
import '../../../../../shared/charts/chart_controller.dart';
import '../../../../../shared/charts/chart_trace.dart' as trace;
import '../../../../../shared/charts/chart_trace.dart'
    show ChartSymbol, ChartType;
import '../../../../../shared/utils.dart';
import '../../../framework/connected/memory_controller.dart';
import '../../../shared/primitives/memory_timeline.dart';

class AndroidChartController extends ChartController {
  AndroidChartController(
    this._memoryController, {
    List<int> sharedLabels = const <int>[],
  }) : super(
          name: 'Android',
          sharedLabelTimestamps: sharedLabels,
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
      final dataLength =
          _memoryController.controllers.chart.memoryTimeline.data.length;

      final dataRange =
          _memoryController.controllers.chart.memoryTimeline.data.getRange(
        chartDataLength,
        dataLength,
      );

      dataRange.forEach(addSample);
    }
  }

  /// Loads all heap samples (live data or offline).
  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.controllers.chart.isPaused) return;

    addTimestamp(sample.timestamp);

    final timestamp = sample.timestamp;
    final adb = sample.adbMemoryInfo;

    final stackValue = adb.stack.toDouble();
    addDataToTrace(
      AndroidTraceName.stack.index,
      trace.Data(timestamp, stackValue),
    );

    final graphicValue = adb.graphics.toDouble();
    addDataToTrace(
      AndroidTraceName.graphics.index,
      trace.Data(
        timestamp,
        graphicValue,
      ),
    );

    final nativeHeapValue = adb.nativeHeap.toDouble();
    addDataToTrace(
      AndroidTraceName.nativeHeap.index,
      trace.Data(
        timestamp,
        nativeHeapValue,
      ),
    );

    final javaHeapValue = adb.javaHeap.toDouble();
    addDataToTrace(
      AndroidTraceName.javaHeap.index,
      trace.Data(timestamp, javaHeapValue),
    );

    final codeValue = adb.code.toDouble();
    addDataToTrace(
      AndroidTraceName.code.index,
      trace.Data(timestamp, codeValue),
    );

    final otherValue = adb.other.toDouble();
    addDataToTrace(
      AndroidTraceName.other.index,
      trace.Data(timestamp, otherValue),
    );

    final systemValue = adb.system.toDouble();
    addDataToTrace(
      AndroidTraceName.system.index,
      trace.Data(timestamp, systemValue),
    );

    final totalValue = adb.total.toDouble();
    addDataToTrace(
      AndroidTraceName.total.index,
      trace.Data(timestamp, totalValue),
    );
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
enum AndroidTraceName {
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
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryAndroidChart> {
  /// Controller attached to the chart.
  AndroidChartController get _chartController => widget.chartController;

  MemoryTimeline get _memoryTimeline =>
      controller.controllers.chart.memoryTimeline;

  @override
  void initState() {
    super.initState();
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
        _processHeapSample(_memoryTimeline.sampleAddedNotifier.value!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultChartHeight,
      child: Chart(_chartController),
    );
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
      assert(_chartController.traces.length == AndroidTraceName.values.length);

      final stackIndex = AndroidTraceName.stack.index;
      assert(
        _chartController.trace(stackIndex).name ==
            AndroidTraceName.values[stackIndex].toString(),
      );

      final graphicsIndex = AndroidTraceName.graphics.index;
      assert(
        _chartController.trace(graphicsIndex).name ==
            AndroidTraceName.values[graphicsIndex].toString(),
      );

      final nativeHeapIndex = AndroidTraceName.nativeHeap.index;
      assert(
        _chartController.trace(nativeHeapIndex).name ==
            AndroidTraceName.values[nativeHeapIndex].toString(),
      );

      final javaHeapIndex = AndroidTraceName.javaHeap.index;
      assert(
        _chartController.trace(javaHeapIndex).name ==
            AndroidTraceName.values[javaHeapIndex].toString(),
      );

      final codeIndex = AndroidTraceName.code.index;
      assert(
        _chartController.trace(codeIndex).name ==
            AndroidTraceName.values[codeIndex].toString(),
      );

      final otherIndex = AndroidTraceName.other.index;
      assert(
        _chartController.trace(otherIndex).name ==
            AndroidTraceName.values[otherIndex].toString(),
      );

      final systemIndex = AndroidTraceName.system.index;
      assert(
        _chartController.trace(systemIndex).name ==
            AndroidTraceName.values[systemIndex].toString(),
      );

      final totalIndex = AndroidTraceName.total.index;
      assert(
        _chartController.trace(totalIndex).name ==
            AndroidTraceName.values[totalIndex].toString(),
      );

      return;
    }

    // Need to create the trace first time.

    // Stack trace
    final stackIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: stackColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.stack.toString(),
    );
    assert(stackIndex == AndroidTraceName.stack.index);
    assert(
      _chartController.trace(stackIndex).name ==
          AndroidTraceName.values[stackIndex].toString(),
    );

    // Java heap trace.
    final javaHeapIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: javaColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.javaHeap.toString(),
    );
    assert(javaHeapIndex == AndroidTraceName.javaHeap.index);
    assert(
      _chartController.trace(javaHeapIndex).name ==
          AndroidTraceName.values[javaHeapIndex].toString(),
    );

    // Code trace
    final codeIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: codeColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.code.toString(),
    );
    assert(codeIndex == AndroidTraceName.code.index);
    assert(
      _chartController.trace(codeIndex).name ==
          AndroidTraceName.values[codeIndex].toString(),
    );

    // Graphics Trace
    final graphicIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: graphicColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.graphics.toString(),
    );
    assert(graphicIndex == AndroidTraceName.graphics.index);
    assert(
      _chartController.trace(graphicIndex).name ==
          AndroidTraceName.values[graphicIndex].toString(),
    );

    // Native heap trace.
    final nativeHeapIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: nativeHeapColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.nativeHeap.toString(),
    );
    assert(nativeHeapIndex == AndroidTraceName.nativeHeap.index);
    assert(
      _chartController.trace(nativeHeapIndex).name ==
          AndroidTraceName.values[nativeHeapIndex].toString(),
    );

    // Other trace
    final otherIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: otherColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.other.toString(),
    );
    assert(otherIndex == AndroidTraceName.other.index);
    assert(
      _chartController.trace(otherIndex).name ==
          AndroidTraceName.values[otherIndex].toString(),
    );

    // System trace
    final systemIndex = _chartController.createTrace(
      ChartType.line,
      trace.PaintCharacteristics(
        color: systemColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.system.toString(),
    );
    assert(systemIndex == AndroidTraceName.system.index);
    assert(
      _chartController.trace(systemIndex).name ==
          AndroidTraceName.values[systemIndex].toString(),
    );

    // Total trace.
    final totalIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: totalColor,
        symbol: ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: AndroidTraceName.total.toString(),
    );
    assert(totalIndex == AndroidTraceName.total.index);
    assert(
      _chartController.trace(totalIndex).name ==
          AndroidTraceName.values[totalIndex].toString(),
    );

    assert(_chartController.traces.length == AndroidTraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (controller.controllers.chart.paused.value) return;
    _chartController.addSample(sample);
  }
}
