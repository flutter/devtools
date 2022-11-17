// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/trace_event.dart';
import '../../../../../primitives/utils.dart';
import '../../../performance_controller.dart';
import '../timeline_events_controller.dart';
import '_perfetto_controller_desktop.dart'
    if (dart.library.html) '_perfetto_controller_web.dart';
import 'perfetto_event_processor.dart';

PerfettoControllerImpl createPerfettoController(
  PerformanceController performanceController,
  TimelineEventsController timelineEventsController,
) {
  return PerfettoControllerImpl(
    performanceController,
    timelineEventsController,
  );
}

abstract class PerfettoController extends DisposableController {
  PerfettoController(
    PerformanceController performanceController,
    this.timelineEventsController,
  ) {
    processor = PerfettoEventProcessor(performanceController);
  }

  String get viewId => '';

  final TimelineEventsController timelineEventsController;

  late final PerfettoEventProcessor processor;

  void init() {}

  Future<void> onBecomingActive() async {}

  Future<void> loadTrace(List<TraceEventWrapper> devToolsTraceEvents) async {}

  Future<void> scrollToTimeRange(TimeRange timeRange) async {}

  Future<void> clear() async {}
}
