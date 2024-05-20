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
class _Colors {
  static final capacity = Colors.grey[400]!;
  static const used = Color(0xff33b5e5);
  static const externals = Color(0xff4ddeff);

  static final rasterLayer = Colors.greenAccent.shade400;
  static const rasterPicture = Color(0xffff4444);
  static final rss = Colors.orange.shade700;
}

class VMChartController extends ChartController {
  VMChartController(this.memoryTimeline, {required this.paused})
      : super(name: 'VM Memory') {
    setupData();

    addAutoDisposeListener(memoryTimeline.sampleAdded, () {
      if (memoryTimeline.sampleAdded.value != null) {
        addSample(memoryTimeline.sampleAdded.value!);
      }
    });
  }

  final ValueListenable<bool> paused;
  final MemoryTimeline memoryTimeline;

  @override
  void setupData() {
    _setupTraces();
    final chartDataLength = timestampsLength;
    final dataLength = memoryTimeline.data.length;

    final dataRange = memoryTimeline.data.getRange(
      chartDataLength,
      dataLength,
    );

    dataRange.forEach(addSample);
  }

  /// Loads all heap samples (live data or offline).
  void addSample(HeapSample sample) {
    // If paused don't update the chart (data is still collected).
    if (paused.value) return;

    addTimestamp(sample.timestamp);

    final timestamp = sample.timestamp;
    final externalValue = sample.external.toDouble();
    addDataToTrace(
      VmTraceName.external.index,
      chart_trace.Data(timestamp, externalValue),
    );

    final usedValue = sample.used.toDouble();
    addDataToTrace(
      VmTraceName.used.index,
      chart_trace.Data(timestamp, usedValue),
    );

    final capacityValue = sample.capacity.toDouble();
    addDataToTrace(
      VmTraceName.capacity.index,
      chart_trace.Data(timestamp, capacityValue),
    );

    final rssValue = sample.rss.toDouble();
    addDataToTrace(
      VmTraceName.rSS.index,
      chart_trace.Data(timestamp, rssValue),
    );

    final rasterLayerValue = sample.rasterCache.layerBytes.toDouble();
    addDataToTrace(
      VmTraceName.rasterLayer.index,
      chart_trace.Data(timestamp, rasterLayerValue),
    );

    final rasterPictureValue = sample.rasterCache.pictureBytes.toDouble();
    addDataToTrace(
      VmTraceName.rasterPicture.index,
      chart_trace.Data(timestamp, rasterPictureValue),
    );
  }

  void _setupTraces() {
    if (traces.isNotEmpty) {
      assert(traces.length == VmTraceName.values.length);

      final externalIndex = VmTraceName.external.index;
      assert(
        trace(externalIndex).name ==
            VmTraceName.values[externalIndex].toString(),
      );

      final usedIndex = VmTraceName.used.index;
      assert(
        trace(usedIndex).name == VmTraceName.values[usedIndex].toString(),
      );

      final capacityIndex = VmTraceName.capacity.index;
      assert(
        trace(capacityIndex).name ==
            VmTraceName.values[capacityIndex].toString(),
      );

      final rSSIndex = VmTraceName.rSS.index;
      assert(
        trace(rSSIndex).name == VmTraceName.values[rSSIndex].toString(),
      );

      final rasterLayerIndex = VmTraceName.rasterLayer.index;
      assert(
        trace(rasterLayerIndex).name ==
            VmTraceName.values[rasterLayerIndex].toString(),
      );

      final rasterPictureIndex = VmTraceName.rasterPicture.index;
      assert(
        trace(rasterPictureIndex).name ==
            VmTraceName.values[rasterPictureIndex].toString(),
      );

      return;
    }

    final externalIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Colors.externals,
        symbol: chart_trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: VmTraceName.external.toString(),
    );
    assert(externalIndex == VmTraceName.external.index);
    assert(
      trace(externalIndex).name == VmTraceName.values[externalIndex].toString(),
    );

    // Used Heap
    final usedIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Colors.used,
        symbol: chart_trace.ChartSymbol.disc,
        diameter: 1.5,
      ),
      stacked: true,
      name: VmTraceName.used.toString(),
    );
    assert(usedIndex == VmTraceName.used.index);
    assert(
      trace(usedIndex).name == VmTraceName.values[usedIndex].toString(),
    );

    // Heap Capacity
    final capacityIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Colors.capacity,
        diameter: 0.0,
        symbol: ChartSymbol.dashedLine,
      ),
      name: VmTraceName.capacity.toString(),
    );
    assert(capacityIndex == VmTraceName.capacity.index);
    assert(
      trace(capacityIndex).name == VmTraceName.values[capacityIndex].toString(),
    );

    // RSS
    final rSSIndex = createTrace(
      ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Colors.rss,
        symbol: ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: VmTraceName.rSS.toString(),
    );
    assert(rSSIndex == VmTraceName.rSS.index);
    assert(
      trace(rSSIndex).name == VmTraceName.values[rSSIndex].toString(),
    );

    final rasterLayerIndex = createTrace(
      chart_trace.ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Colors.rasterLayer,
        symbol: chart_trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: VmTraceName.rasterLayer.toString(),
    );
    assert(rasterLayerIndex == VmTraceName.rasterLayer.index);
    assert(
      trace(rasterLayerIndex).name ==
          VmTraceName.values[rasterLayerIndex].toString(),
    );

    final rasterPictureIndex = createTrace(
      chart_trace.ChartType.line,
      chart_trace.PaintCharacteristics(
        color: _Colors.rasterPicture,
        symbol: chart_trace.ChartSymbol.dashedLine,
        strokeWidth: 2,
      ),
      name: VmTraceName.rasterPicture.toString(),
    );
    assert(rasterPictureIndex == VmTraceName.rasterPicture.index);
    assert(
      trace(rasterPictureIndex).name ==
          VmTraceName.values[rasterPictureIndex].toString(),
    );

    assert(traces.length == VmTraceName.values.length);
  }
}
