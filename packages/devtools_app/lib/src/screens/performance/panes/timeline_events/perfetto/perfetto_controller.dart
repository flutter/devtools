// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';

import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/utils.dart';
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

  final TimelineEventsController timelineEventsController;

  late final PerfettoEventProcessor processor;

  void init() {}

  void onBecomingActive() {}

  Future<void> loadTrace(List<TraceEventWrapper> devToolsTraceEvents) async {}

  void scrollToTimeRange(TimeRange timeRange) {}

  void showHelpMenu() {}

  Future<void> clear() async {}
}
