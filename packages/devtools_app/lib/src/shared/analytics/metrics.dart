// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'analytics_common.dart';

class MemoryScreenMetrics extends ScreenAnalyticsMetrics {
  MemoryScreenMetrics({
    this.heapObjectsTotal,
    this.heapDiffObjectsBefore,
    this.heapDiffObjectsAfter,
  });

  /// The number of objects in the 'before' heap for a diff calculation (used to
  /// provide scale for timing measurements).
  final int? heapDiffObjectsBefore;

  /// The number of objects in the 'after' heap for a diff calculation (used to
  /// provide scale for timing measurements).
  final int? heapDiffObjectsAfter;

  /// The number of objects in a heap snapshot that was captured.
  final int? heapObjectsTotal;
}

class PerformanceScreenMetrics extends ScreenAnalyticsMetrics {
  PerformanceScreenMetrics({
    this.uiDuration,
    this.rasterDuration,
    this.shaderCompilationDuration,
    this.traceEventCount,
  });

  /// The duration in microseconds for the UI time of a selected [FlutterFrame].
  final Duration? uiDuration;

  /// The duration in microseconds for the Raster time of a selected
  /// [FlutterFrame].
  final Duration? rasterDuration;

  /// The duration in microseconds for the shader compilation time of a selected
  /// [FlutterFrame].
  final Duration? shaderCompilationDuration;

  /// The number of trace events that were processed (used to provide scale for
  /// timing measurements).
  final int? traceEventCount;
}

class ProfilerScreenMetrics extends ScreenAnalyticsMetrics {
  ProfilerScreenMetrics({
    required this.cpuSampleCount,
    required this.cpuStackDepth,
  });

  /// The number of CPU samples that were processed for a profile (used along
  /// with [cpuStackDepth] to provide scale for timing measurements).
  final int cpuSampleCount;

  /// The stack depth for a profile (used along with [cpuSampleCount] to provide
  /// scale for timing measurements).
  final int cpuStackDepth;
}

class InspectorScreenMetrics extends ScreenAnalyticsMetrics {
  InspectorScreenMetrics({
    required this.rootSetCount,
    required this.rowCount,
    required this.inspectorTreeControllerId,
  });

  static const int summaryTreeGaId = 0;
  static const int detailsTreeGaId = 1;

  /// The number of times the root has been set, since the
  /// [InspectorTreeController] with id [inspectorTreeControllerId], has been
  /// initialized.
  final int? rootSetCount;

  /// The number of rows that are in the root being shown to the user, from the
  /// [InspectorTreeController] with id [inspectorTreeControllerId].
  final int? rowCount;

  /// The id of the [InspectorTreeController], for which this event is tracking.
  final int? inspectorTreeControllerId;
}
