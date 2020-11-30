// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/chart.dart';
import '../charts/chart_controller.dart';
import '../charts/chart_trace.dart' as trace;
import '../theme.dart';

import 'memory_controller.dart';
import 'memory_timeline.dart';

class AndroidChartController extends ChartController {
  AndroidChartController(this._memoryController)
      : super(
          displayTopLine: false,
          name: 'Android',
        );

  final MemoryController _memoryController;

  // TODO(terry): Only load max visible data collected, when pruning of data
  //              charted is added.
  /// Preload any existing data collected but not in the chart.
  @override
  void setupData() {
    final chartDataLength = timestampsSize;
    final dataLength = _memoryController.memoryTimeline.data.length;

    final dataRange = _memoryController.memoryTimeline.data.getRange(
      chartDataLength,
      dataLength,
    );

    dataRange.forEach(addSampleToChart);
  }

  /// Loads all heap samples (live data or offline).
  void addSampleToChart(HeapSample sample) {
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
        ));

    final nativeHeapValue = adb.nativeHeap.toDouble();
    addDataToTrace(
        TraceName.nativeHeap.index,
        trace.Data(
          timestamp,
          nativeHeapValue,
        ));

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
  const MemoryAndroidChart(this.chartController);

  final AndroidChartController chartController;

  @override
  MemoryAndroidChartState createState() => MemoryAndroidChartState();
}

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum TraceName {
  stack,
  graphics,
  nativeHeap,
  javaHeap,
  code,
  other,
  system,
  total,
}

class MemoryAndroidChartState extends State<MemoryAndroidChart>
    with AutoDisposeMixin {
  /// Controller attached to the chart.
  AndroidChartController get _chartController => widget.chartController;

  /// Controller for managing memory collection.
  MemoryController _memoryController;

  MemoryTimeline get _memoryTimeline => _memoryController.memoryTimeline;

  ColorScheme colorScheme;

  @override
  void initState() {
    super.initState();

    setupTraces();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _memoryController = Provider.of<MemoryController>(context);

    // TODO(jacobr): this is an ugly way to be using the theme. It would be
    // better if the controllers weren't involved with the color scheme.
    colorScheme = Theme.of(context).colorScheme;

    //_initController(colorScheme);

    cancel();

    setupTraces();
    _chartController.setupData();

    addAutoDisposeListener(_memoryTimeline.sampleAddedNotifier, () {
      _processHeapSample(_memoryTimeline.sampleAddedNotifier.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chartController != null) {
      if (_chartController.timestamps.isNotEmpty) {
        return Container(
            child: Chart(_chartController), height: defaultChartHeight);
      }
    }

    return const SizedBox(width: denseSpacing);
  }

  /// TODO(terry): Colors used in charts (move to theme).
  static const haloBlue = Color.fromARGB(255, 51, 181, 229);
  static const holoOrangeDark = Color(0xffff8800);
  static const holoBlueLight = Color(0xff33b5e5);
  static const holoPurple = Color(0xffaa66cc);
  static const holoGreenDark = Color(0xff669900);
  static const lightGray = Color(0xFFCCCCCC);

  void setupTraces() {
    if (_chartController.traces.isNotEmpty) {
      assert(_chartController.traces.length == TraceName.values.length);

      final stackIndex = TraceName.stack.index;
      assert(_chartController.trace(stackIndex).name ==
          TraceName.values[stackIndex].toString());

      final graphicsIndex = TraceName.graphics.index;
      assert(_chartController.trace(graphicsIndex).name ==
          TraceName.values[graphicsIndex].toString());

      final nativeHeapIndex = TraceName.nativeHeap.index;
      assert(_chartController.trace(nativeHeapIndex).name ==
          TraceName.values[nativeHeapIndex].toString());

      final javaHeapIndex = TraceName.javaHeap.index;
      assert(_chartController.trace(javaHeapIndex).name ==
          TraceName.values[javaHeapIndex].toString());

      final codeIndex = TraceName.code.index;
      assert(_chartController.trace(codeIndex).name ==
          TraceName.values[codeIndex].toString());

      final otherIndex = TraceName.other.index;
      assert(_chartController.trace(otherIndex).name ==
          TraceName.values[otherIndex].toString());

      final systemIndex = TraceName.system.index;
      assert(_chartController.trace(systemIndex).name ==
          TraceName.values[systemIndex].toString());

      final totalIndex = TraceName.total.index;
      assert(_chartController.trace(totalIndex).name ==
          TraceName.values[totalIndex].toString());

      return;
    }

    // Need to create the trace first time.
    final stackIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: Colors.white,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      name: TraceName.stack.toString(),
    );
    assert(stackIndex == TraceName.stack.index);
    assert(_chartController.trace(stackIndex).name ==
        TraceName.values[stackIndex].toString());

    final graphicIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: holoOrangeDark,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      name: TraceName.graphics.toString(),
    );
    assert(graphicIndex == TraceName.graphics.index);
    assert(_chartController.trace(graphicIndex).name ==
        TraceName.values[graphicIndex].toString());

    final nativeHeapIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: holoBlueLight,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      name: TraceName.nativeHeap.toString(),
    );
    assert(nativeHeapIndex == TraceName.nativeHeap.index);
    assert(_chartController.trace(nativeHeapIndex).name ==
        TraceName.values[nativeHeapIndex].toString());

    final javaHeapIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: Colors.yellow,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      name: TraceName.javaHeap.toString(),
    );
    assert(javaHeapIndex == TraceName.javaHeap.index);
    assert(_chartController.trace(javaHeapIndex).name ==
        TraceName.values[javaHeapIndex].toString());

    final codeIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: Colors.grey,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      name: TraceName.code.toString(),
    );
    assert(codeIndex == TraceName.code.index);
    assert(_chartController.trace(codeIndex).name ==
        TraceName.values[codeIndex].toString());

    final otherIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: holoPurple,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      name: TraceName.other.toString(),
    );
    assert(otherIndex == TraceName.other.index);
    assert(_chartController.trace(otherIndex).name ==
        TraceName.values[otherIndex].toString());

    final systemIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: holoGreenDark,
        symbol: trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      name: TraceName.system.toString(),
    );
    assert(systemIndex == TraceName.system.index);
    assert(_chartController.trace(systemIndex).name ==
        TraceName.values[systemIndex].toString());

    final totalIndex = _chartController.createTrace(
      trace.ChartType.line,
      trace.PaintCharacteristics(
        color: lightGray,
        symbol: trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: TraceName.total.toString(),
    );
    assert(totalIndex == TraceName.total.index);
    assert(_chartController.trace(totalIndex).name ==
        TraceName.values[totalIndex].toString());

    assert(_chartController.traces.length == TraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void _processHeapSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (_memoryController.paused.value) return;
    _chartController.addSampleToChart(sample);
  }
}
