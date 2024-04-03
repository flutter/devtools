// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/charts/chart_controller.dart';
import '../../../../../shared/charts/chart_trace.dart' as trace;
import '../../../shared/primitives/memory_timeline.dart';

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

class AndroidChartController extends ChartController {
  AndroidChartController(
    this.memoryTimeline, {
    required this.paused,
    List<int> sharedLabels = const <int>[],
  }) : super(
          name: 'Android',
          sharedLabelTimestamps: sharedLabels,
        );

  ValueListenable<bool> paused;
  MemoryTimeline memoryTimeline;

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
