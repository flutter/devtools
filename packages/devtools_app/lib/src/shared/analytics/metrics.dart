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

  final int? heapDiffObjectsBefore;
  final int? heapDiffObjectsAfter;
  final int? heapObjectsTotal;
}

class PerformanceScreenMetrics extends ScreenAnalyticsMetrics {
  PerformanceScreenMetrics({
    this.uiDuration,
    this.rasterDuration,
    this.shaderCompilationDuration,
    this.traceEventCount,
  });

  final Duration? uiDuration;
  final Duration? rasterDuration;
  final Duration? shaderCompilationDuration;
  final int? traceEventCount;
}

class ProfilerScreenMetrics extends ScreenAnalyticsMetrics {
  ProfilerScreenMetrics({
    required this.cpuSampleCount,
    required this.cpuStackDepth,
  });

  final int cpuSampleCount;
  final int cpuStackDepth;
}
