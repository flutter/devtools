// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:devtools_app_shared/utils.dart';

import '../../../../../shared/primitives/utils.dart';
import '../../../performance_controller.dart';
import '../timeline_event_processor.dart';
import '../timeline_events_controller.dart';
import '_perfetto_controller_desktop.dart'
    if (dart.library.js_interop) '_perfetto_controller_web.dart';

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
    processor = FlutterTimelineEventProcessor(performanceController);
  }

  final TimelineEventsController timelineEventsController;

  /// Responsible for processing Perfetto events when loading a trace that was
  /// collected from a Flutter app.
  ///
  /// For non-flutter apps, this processor will not be used.
  late final FlutterTimelineEventProcessor processor;

  void init() {}

  void onBecomingActive() {}

  Future<void> loadTrace(Uint8List traceBinary) async {}

  void scrollToTimeRange(TimeRange timeRange) {}

  void showHelpMenu() {}

  Future<void> clear() async {}
}
