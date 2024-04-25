// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';

import '../../../../../../shared/charts/chart_controller.dart';
import '../../../../../../shared/charts/chart_trace.dart' as chart_trace;
import '../../../../shared/primitives/memory_timeline.dart';
import '../../data/charts.dart';

class VMChartController extends ChartController {
  VMChartController(this.memoryTimeline, {required this.paused})
      : super(name: 'VM Memory');

  final ValueListenable<bool> paused;
  final MemoryTimeline memoryTimeline;

  // TODO(terry): Only load max visible data collected, when pruning of data
  //              charted is added.
  /// Preload any existing data collected but not in the chart.
  @override
  void setupData() {
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
}
