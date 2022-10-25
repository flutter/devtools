// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

import '../../../../../primitives/trace_event.dart';
import '../../../../../primitives/utils.dart';
import '../../../performance_controller.dart';

const String _uiEventName = 'Animator::BeginFrame';

/// Processes a recorded list of trace events and pulls out any meaningful
/// information.
///
/// For a Flutter app, the meaningful information the processor finds is the
/// range of Flutter frames included in the list of trace events and the clock
/// offset between the trace events and the flutter frame events.
class PerfettoEventProcessor {
  PerfettoEventProcessor(this.performanceController);

  final PerformanceController performanceController;

  // TODO(kenz): investigate whether there is still a divergence in the
  // vm timeline clock and the clock used by the Flutter.Frame events. If there
  // is no longer a divergence, we can remove this code to calculate the clock
  // offset.
  /// The offset between the clock used by the VM timeline and the clock used
  /// in the 'Flutter.Frame' events.
  ///
  /// We need to take this offset into account when sending an event to Perfetto
  /// to scroll to a Flutter Frame's time range.
  Duration? clockOffsetMicros;

  /// The frame range that we have processed timeline events for.
  Range? get frameRangeFromTimelineEvents =>
      _startFrameId == null || _endFrameId == null
          ? null
          : Range(_startFrameId!, _endFrameId!);
  int? _startFrameId;
  int? _endFrameId;

  bool hasProcessedEventsForFrame(int frameId) {
    return frameRangeFromTimelineEvents?.contains(frameId) ?? false;
  }

  void processTraceEvents(List<TraceEventWrapper> traceEvents) {
    for (final eventWrapper in traceEvents) {
      performanceController.recordTrace(eventWrapper.event.json);
      final frameNumberFromEvent = eventWrapper.flutterFrameNumber;
      if (frameNumberFromEvent != null) {
        _startFrameId ??= frameNumberFromEvent;
        // We process events in timestamp order, so [_endFrameId] will always be
        // reassigned.
        _endFrameId = frameNumberFromEvent;

        if (clockOffsetMicros == null &&
            eventWrapper.isUiFrameIdentifier &&
            eventWrapper.event.phase == 'B') {
          final frameMatch = performanceController.flutterFrames.value
              .firstWhereOrNull((frame) => frame.id == frameNumberFromEvent);
          if (frameMatch != null) {
            final timeStartFromFrame =
                frameMatch.timeFromFrameTiming.start!.inMicroseconds;
            final timeStartFromEvent = eventWrapper.event.timestampMicros!;
            clockOffsetMicros =
                Duration(microseconds: timeStartFromEvent - timeStartFromFrame);
            return;
          }
        }
      }
    }
  }

  void reset() {
    _startFrameId = null;
    _endFrameId = null;
    clockOffsetMicros = null;
  }
}

extension FrameIdentifierExtension on TraceEventWrapper {
  /// Whether this event is contains the flutter frame identifier for the UI
  /// thread in its trace event args.
  bool get isUiFrameIdentifier =>
      event.name == _uiEventName &&
      event.args!.containsKey(TraceEvent.frameNumberArg);

  int? get flutterFrameNumber {
    final frameNumber = event.args![TraceEvent.frameNumberArg];
    return frameNumber != null ? int.tryParse(frameNumber) : null;
  }
}
