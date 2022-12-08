// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../performance_model.dart';
import '../timeline_event_processor.dart';

// For documentation on the Chrome "Trace Event Format", see this document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview

// TODO(kenz): consider handling only duration events associated with flutter
// frames (events that have the flutter frame number argument and their
// children). This would limit the risk of bad data outside of flutter frame
// timeline events messing up event processing, and could potentially improve
// performance since we'd be processing fewer events.

/// Processor for composing a recorded list of trace events into a timeline of
/// [SyncTimelineEvent].
///
/// This processor only handles Duration events (synchronous), because these are
/// the only events that we use in the Performance page for purposes outside of
/// viewing traces. The perfetto trace viewer does not use the
/// [SyncTimelineEvent] objects (it uses the trace json directly to load data
/// into the viewer), but other parts of the Performance page, like the frame
/// analysis tab, do use these Dart timeline objects.
class PerfettoEventProcessor extends BaseTraceEventProcessor {
  PerfettoEventProcessor(super.performanceController);

  /// The frame range that we have processed timeline events for.
  Range? get frameRangeFromTimelineEvents =>
      _startFrameId == null || _endFrameId == null
          ? null
          : Range(_startFrameId!, _endFrameId!);
  int? _startFrameId;
  int? _endFrameId;

  /// Returns whether we have processed the trace events that correspond to the
  /// Flutter frame with id [frameId].
  bool hasProcessedEventsForFrame(int frameId) {
    return frameRangeFromTimelineEvents?.contains(frameId) ?? false;
  }

  @override
  @protected
  void processTraceEvents(List<TraceEventWrapper> events) {
    for (final eventWrapper in events) {
      eventsController.recordTrace(eventWrapper.event.json);
      final frameNumberFromEvent = eventWrapper.flutterFrameNumber;
      if (frameNumberFromEvent != null) {
        _startFrameId ??= frameNumberFromEvent;
        // We process events in timestamp order, so [_endFrameId] will always be
        // reassigned.
        _endFrameId = max(_endFrameId ?? -1, frameNumberFromEvent);
      }

      if (eventWrapper.event.timestampMicros == null) continue;

      eventWrapper.event.type = inferEventType(eventWrapper.event);

      // Add [pendingRootCompleteEvent] to the timeline if it is ready.
      addPendingCompleteRootToTimeline(
        currentProcessingTime: eventWrapper.event.timestampMicros,
      );

      switch (eventWrapper.event.phase) {
        case TraceEvent.durationBeginPhase:
          handleDurationBeginEvent(eventWrapper);
          break;
        case TraceEvent.durationEndPhase:
          handleDurationEndEvent(eventWrapper);
          break;
        case TraceEvent.durationCompletePhase:
          handleDurationCompleteEvent(eventWrapper);
          break;
        default:
          break;
      }
    }
  }

  @override
  void reset() {
    super.reset();
    _startFrameId = null;
    _endFrameId = null;
  }
}

extension FrameIdentifierExtension on TraceEventWrapper {
  /// Returns the flutter frame number for this trace event, or null if it does
  /// not exist.
  int? get flutterFrameNumber {
    final frameNumber = event.args?[TraceEvent.frameNumberArg];
    if (frameNumber == null) return null;
    return int.tryParse(frameNumber);
  }
}
