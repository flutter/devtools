// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/charts/chart_controller.dart';
import '../../../../../../shared/charts/chart_trace.dart' as chart_trace;
import '../../../../../../shared/charts/chart_trace.dart'
    show ChartType, ChartSymbol;
import '../../../../shared/primitives/memory_timeline.dart';
import '../../data/charts.dart';

// ignore: avoid_classes_with_only_static_members, enum-like classes are ok
class _Color {
  static const otherColor = Color(0xffff8800); // HoloOrangeDark;
  static const nativeHeapColor = Color(0xff33b5e5); // HoloBlueLight
  static final graphicColor = Colors.greenAccent.shade400;
  static const codeColor = Color(0xffaa66cc); // HoloPurple
  static const javaColor = Colors.yellow;
  static const stackColor = Colors.tealAccent;
  static const systemColor = Color(0xff669900); // HoloGreenDark
  static final totalColor = Colors.blueGrey.shade100;
}

class AndroidChartController extends ChartController {
  AndroidChartController(
    this.memoryTimeline, {
    required this.paused,
    List<int> sharedLabels = const <int>[],
  }) : super(
          name: 'Android',
          sharedLabelTimestamps: sharedLabels,
        ) {
    setupTraces();
    setupData();

    addAutoDisposeListener(memoryTimeline.sampleAdded, () {
      if (memoryTimeline.sampleAdded.value != null) {
        addSample(memoryTimeline.sampleAdded.value!);
      }
    });
  }

  final ValueListenable<bool> paused;
  final MemoryTimeline memoryTimeline;

  // TODO(terry): Only load max visible data collected, when pruning of data
  //              charted is added.
  /// Preload any existing data collected but not in the chart.
  @override
  void setupData() {
    // Only display if traces have been created. Android memory may not
    // have been toggled to be displayed - yet.
    if (traces.isNotEmpty) {
      final chartDataLength = timestampsLength;
      final dataLength = memoryTimeline.data.length;

      final dataRange = memoryTimeline.data.getRange(
        chartDataLength,
        dataLength,
      );

      dataRange.forEach(addSample);
    }
  }

  void setupTraces() {
    if (traces.isNotEmpty) {
      assert(traces.length == AndroidTraceName.values.length);

      final stackIndex = AndroidTraceName.stack.index;
      assert(
        trace(stackIndex).name ==
            AndroidTraceName.values[stackIndex].toString(),
      );

      final graphicsIndex = AndroidTraceName.graphics.index;
      assert(
        trace(graphicsIndex).name ==
            AndroidTraceName.values[graphicsIndex].toString(),
      );

      final nativeHeapIndex = AndroidTraceName.nativeHeap.index;
      assert(
        trace(nativeHeapIndex).name ==
            AndroidTraceName.values[nativeHeapIndex].toString(),
      );

      final javaHeapIndex = AndroidTraceName.javaHeap.index;
      assert(
        trace(javaHeapIndex).name ==
            AndroidTraceName.values[javaHeapIndex].toString(),
      );

      final codeIndex = AndroidTraceName.code.index;
      assert(
        trace(codeIndex).name == AndroidTraceName.values[codeIndex].toString(),
      );

      final otherIndex = AndroidTraceName.other.index;
      assert(
        trace(otherIndex).name ==
            AndroidTraceName.values[otherIndex].toString(),
      );

      final systemIndex = AndroidTraceName.system.index;
      assert(
        trace(systemIndex).name ==
            AndroidTraceName.values[systemIndex].toString(),
      );

      final totalIndex = AndroidTraceName.total.index;
      assert(
        trace(totalIndex).name ==
            AndroidTraceName.values[totalIndex].toString(),
      );

      return;
    }

    // Need to create the trace first time.

    // Stack trace
    final stackIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.stackColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.stack.toString(),
    );
    assert(stackIndex == AndroidTraceName.stack.index);
    assert(
      trace(stackIndex).name == AndroidTraceName.values[stackIndex].toString(),
    );

    // Java heap trace.
    final javaHeapIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.javaColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.javaHeap.toString(),
    );
    assert(javaHeapIndex == AndroidTraceName.javaHeap.index);
    assert(
      trace(javaHeapIndex).name ==
          AndroidTraceName.values[javaHeapIndex].toString(),
    );

    // Code trace
    final codeIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.codeColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.code.toString(),
    );
    assert(codeIndex == AndroidTraceName.code.index);
    assert(
      trace(codeIndex).name == AndroidTraceName.values[codeIndex].toString(),
    );

    // Graphics Trace
    final graphicIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.graphicColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.graphics.toString(),
    );
    assert(graphicIndex == AndroidTraceName.graphics.index);
    assert(
      trace(graphicIndex).name ==
          AndroidTraceName.values[graphicIndex].toString(),
    );

    // Native heap trace.
    final nativeHeapIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.nativeHeapColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.nativeHeap.toString(),
    );
    assert(nativeHeapIndex == AndroidTraceName.nativeHeap.index);
    assert(
      trace(nativeHeapIndex).name ==
          AndroidTraceName.values[nativeHeapIndex].toString(),
    );

    // Other trace
    final otherIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.otherColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.other.toString(),
    );
    assert(otherIndex == AndroidTraceName.other.index);
    assert(
      trace(otherIndex).name == AndroidTraceName.values[otherIndex].toString(),
    );

    // System trace
    final systemIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.systemColor,
        symbol: ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: AndroidTraceName.system.toString(),
    );
    assert(systemIndex == AndroidTraceName.system.index);
    assert(
      trace(systemIndex).name ==
          AndroidTraceName.values[systemIndex].toString(),
    );

    // Total trace.
    final totalIndex = createTrace(
      chart_trace.ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Color.totalColor,
        symbol: ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: AndroidTraceName.total.toString(),
    );
    assert(totalIndex == AndroidTraceName.total.index);
    assert(
      trace(totalIndex).name == AndroidTraceName.values[totalIndex].toString(),
    );

    assert(traces.length == AndroidTraceName.values.length);
  }

  /// Loads all heap samples (live data or offline).
  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (paused.value) return;

    addTimestamp(sample.timestamp);

    final timestamp = sample.timestamp;
    final adb = sample.adbMemoryInfo;

    final stackValue = adb.stack.toDouble();
    addDataToTrace(
      AndroidTraceName.stack.index,
      chart_trace.Data(timestamp, stackValue),
    );

    final graphicValue = adb.graphics.toDouble();
    addDataToTrace(
      AndroidTraceName.graphics.index,
      chart_trace.Data(
        timestamp,
        graphicValue,
      ),
    );

    final nativeHeapValue = adb.nativeHeap.toDouble();
    addDataToTrace(
      AndroidTraceName.nativeHeap.index,
      chart_trace.Data(
        timestamp,
        nativeHeapValue,
      ),
    );

    final javaHeapValue = adb.javaHeap.toDouble();
    addDataToTrace(
      AndroidTraceName.javaHeap.index,
      chart_trace.Data(timestamp, javaHeapValue),
    );

    final codeValue = adb.code.toDouble();
    addDataToTrace(
      AndroidTraceName.code.index,
      chart_trace.Data(timestamp, codeValue),
    );

    final otherValue = adb.other.toDouble();
    addDataToTrace(
      AndroidTraceName.other.index,
      chart_trace.Data(timestamp, otherValue),
    );

    final systemValue = adb.system.toDouble();
    addDataToTrace(
      AndroidTraceName.system.index,
      chart_trace.Data(timestamp, systemValue),
    );

    final totalValue = adb.total.toDouble();
    addDataToTrace(
      AndroidTraceName.total.index,
      chart_trace.Data(timestamp, totalValue),
    );
  }
}
