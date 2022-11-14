// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../../primitives/trace_event.dart';
import '../../../../../primitives/utils.dart';
import '../../../performance_controller.dart';

class PerfettoController {
  PerfettoController(this.performanceController);

  final PerformanceController performanceController;

  void init() {}

  void dispose() {}

  Future<void> onBecomingActive() async {}

  Future<void> loadTrace(List<TraceEventWrapper> devToolsTraceEvents) async {}

  Future<void> scrollToTimeRange(TimeRange timeRange) async {}

  Future<void> clear() async {}
}
