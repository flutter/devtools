// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../../shared/config_specific/logger/logger.dart';
import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../performance_model.dart';
import '../timeline_event_processor.dart';

/// Processor for composing a recorded list of trace events into a timeline of
/// [AsyncTimelineEvent]s, [SyncTimelineEvent]s, and [FlutterFrame]s.
///
/// This processor should only be used when the legacy trace event viewer is in
/// use.
class LegacyEventProcessor extends BaseTraceEventProcessor {
  LegacyEventProcessor(super.performanceController);

  /// Number of traceEvents we will process in each batch.
  static const _defaultBatchSize = 2000;

  /// Notifies with the current progress value of processing Timeline data.
  ///
  /// This value should sit between 0.0 and 1.0.
  ValueListenable<double> get progressNotifier => _progressNotifier;
  final _progressNotifier = ValueNotifier<double>(0.0);

  int _traceEventsProcessed = 0;

  /// Async timeline events we have processed, mapped to their respective async
  /// ids.
  ///
  /// The id keys should be of the form <category>:<scope>:<id> or
  /// <category>:<id> if scope is null. See [TraceEvent.asyncUID].
  final _asyncEventsById = <String, AsyncTimelineEvent>{};

  @override
  FutureOr<void> processData(
    List<TraceEventWrapper> traceEvents, {
    int startIndex = 0,
  }) async {
    resetProcessingData();
    await super.processData(traceEvents, startIndex: startIndex);
    resetProcessingData();
  }

  @override
  @protected
  Future<void> processTraceEvents(List<TraceEventWrapper> events) async {
    // At minimum, process the data in 4 batches to smooth the appearance of
    // the progress indicator.
    final batchSize =
        math.min(_defaultBatchSize, math.max(1, events.length / 4)).round();

    while (_traceEventsProcessed < events.length) {
      _processBatch(batchSize, events);
      _progressNotifier.value = _traceEventsProcessed / events.length;

      // Await a small delay to give the UI thread a chance to update the
      // progress indicator.
      await delayForBatchProcessing();
    }
  }

  void _processBatch(int batchSize, List<TraceEventWrapper> traceEvents) {
    final batchEnd =
        math.min(_traceEventsProcessed + batchSize, traceEvents.length);
    for (int i = _traceEventsProcessed; i < batchEnd; i++) {
      final eventWrapper = traceEvents[i];
      _traceEventsProcessed++;
      eventsController.recordTrace(eventWrapper.event.json);

      if (eventWrapper.event.timestampMicros == null) continue;

      // TODO(kenz): stop manually setting the type once we have that data
      // from the engine.
      eventWrapper.event.type = inferEventType(eventWrapper.event);

      // Add [pendingRootCompleteEvent] to the timeline if it is ready.
      addPendingCompleteRootToTimeline(
        currentProcessingTime: eventWrapper.event.timestampMicros,
      );

      switch (eventWrapper.event.phase) {
        case TraceEvent.asyncBeginPhase:
        case TraceEvent.asyncInstantPhase:
          _addAsyncEvent(eventWrapper);
          break;
        case TraceEvent.asyncEndPhase:
          _endAsyncEvent(eventWrapper);
          break;
        case TraceEvent.durationBeginPhase:
          handleDurationBeginEvent(eventWrapper);
          break;
        case TraceEvent.durationEndPhase:
          handleDurationEndEvent(eventWrapper);
          break;
        case TraceEvent.durationCompletePhase:
          handleDurationCompleteEvent(eventWrapper);
          break;
        // TODO(kenz): add support for instant events
        // https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview#heading=h.lenwiilchoxp
        // TODO(kenz): add support for flows.
        // https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview#heading=h.4qqub5rv9ybk
        default:
          break;
      }
    }
  }

  @override
  @protected
  void postProcessData() {
    final idsToRemove = <String>[];
    for (var rootEvent in _asyncEventsById.values.where((e) => e.isRoot)) {
      // Do not add incomplete async trees to the timeline.
      // TODO(kenz): infer missing end times based on other end times in the
      // async event tree. Add these "repaired" events to the timeline.
      if (!rootEvent.isWellFormedDeep) continue;

      eventsController.addTimelineEvent(rootEvent);
      idsToRemove.add(rootEvent.asyncUID);
    }
    idsToRemove.forEach(_asyncEventsById.remove);

    _setTimeForData();
  }

  void _setTimeForData() {
    final _data = performanceController.data!;
    _data.timelineEvents.sort(
      (a, b) =>
          a.time.start!.inMicroseconds.compareTo(b.time.start!.inMicroseconds),
    );
    if (_data.timelineEvents.isNotEmpty) {
      _data.time = TimeRange()
        // We process trace events in timestamp order, so we can ensure the first
        // trace event has the earliest starting timestamp.
        ..start = Duration(
          microseconds: _data.timelineEvents.first.time.start!.inMicroseconds,
        )
        // We cannot guarantee that the last trace event is the latest timestamp
        // in the timeline. DurationComplete events' timestamps refer to their
        // starting timestamp, but their end time is derived from the same trace
        // via the "dur" field. For this reason, we use the cached value stored in
        // [timelineController.fullTimeline].
        ..end = Duration(microseconds: _data.endTimestampMicros);
    } else {
      _data.time = TimeRange()
        ..start = Duration.zero
        ..end = Duration.zero;
    }
  }

  void _addAsyncEvent(TraceEventWrapper eventWrapper) {
    final timelineEvent = AsyncTimelineEvent(eventWrapper);
    if (eventWrapper.event.phase == TraceEvent.asyncInstantPhase) {
      timelineEvent.time.end = timelineEvent.time.start;
    }

    // If parentId is specified, use it to define the async tree structure.
    if (timelineEvent.hasExplicitParent) {
      final parent = _asyncEventsById[timelineEvent.parentAsyncUID];
      if (parent != null) {
        parent.addChild(timelineEvent);
      }
      _asyncEventsById[eventWrapper.event.asyncUID] = timelineEvent;
      return;
    }

    final currentEventWithId = _asyncEventsById[eventWrapper.event.asyncUID];

    // If we already have a timeline event with the same async id as
    // [timelineEvent] (e.g. [currentEventWithId]), then [timelineEvent] is
    // either a child of [currentEventWithId] or a new root event with this id.
    if (currentEventWithId != null) {
      if (currentEventWithId.isWellFormedDeep) {
        // [timelineEvent] is a new root with the same id as
        // [currentEventWithId]. Since [currentEventWithId] is well formed, add
        // it to the timeline.
        eventsController.addTimelineEvent(currentEventWithId);
        _asyncEventsById[eventWrapper.event.asyncUID] = timelineEvent;
      } else {
        if (eventWrapper.event.phase != TraceEvent.asyncInstantPhase &&
            currentEventWithId.isWellFormed) {
          // Since this is not an async instant event and the parent id was not
          // explicitly passed in the event args, and since we process events in
          // timestamp order, if [currentEventWithId] is well formed,
          // [timelineEvent] cannot be a child of [currentEventWithId]. This is
          // an illegal id collision that we need to handle gracefully, so throw
          // this event away. Bug tracking collisions:
          // https://github.com/flutter/flutter/issues/47019.
          log('Id collision on id ${eventWrapper.event.id}', LogLevel.warning);
        } else {
          // We know it must be a child because we process events in timestamp
          // order.
          currentEventWithId.addChild(timelineEvent);
        }
      }
    } else {
      _asyncEventsById[eventWrapper.event.asyncUID] = timelineEvent;
    }
  }

  void _endAsyncEvent(TraceEventWrapper eventWrapper) {
    final AsyncTimelineEvent? root =
        _asyncEventsById[eventWrapper.event.asyncUID];
    if (root == null) {
      // Since we process trace events in timestamp order, we can guarantee that
      // we have not already processed the matching begin event. Discard the end
      // event in this case.
      return;
    }
    root.endAsyncEvent(eventWrapper);
  }

  @override
  void reset() {
    super.reset();
    _asyncEventsById.clear();
    resetProcessingData();
  }

  void resetProcessingData() {
    _traceEventsProcessed = 0;
    _progressNotifier.value = 0.0;
  }
}
