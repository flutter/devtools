// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../config_specific/logger/logger.dart';
import '../../primitives/trace_event.dart';
import '../../primitives/utils.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_utils.dart';

// For documentation, see the Chrome "Trace Event Format" document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU.
// This class depends on the stability of event names we receive from the
// engine. That dependency is tracked at
// https://github.com/flutter/flutter/issues/27609.

const String rasterEventName = 'GPURasterizer::Draw';

const String rasterEventNameWithFrameNumber = 'Rasterizer::DoDraw';

const String uiEventName = 'Animator::BeginFrame';

/// Processor for composing a recorded list of trace events into a timeline of
/// [AsyncTimelineEvent]s, [SyncTimelineEvent]s, and [FlutterFrame]s.
class TimelineEventProcessor {
  TimelineEventProcessor(this.performanceController);

  /// Number of traceEvents we will process in each batch.
  static const _defaultBatchSize = 2000;

  final PerformanceController performanceController;

  /// Notifies with the current progress value of processing Timeline data.
  ///
  /// This value should sit between 0.0 and 1.0.
  ValueListenable get progressNotifier => _progressNotifier;
  final _progressNotifier = ValueNotifier<double>(0.0);

  int _traceEventsProcessed = 0;

  /// Async timeline events we have processed, mapped to their respective async
  /// ids.
  ///
  /// The id keys should be of the form <category>:<scope>:<id> or
  /// <category>:<id> if scope is null. See [TraceEvent.asyncUID].
  final _asyncEventsById = <String, AsyncTimelineEvent>{};

  /// The current timeline event nodes for duration events.
  ///
  /// The events are mapped to their thread id. As we process duration events,
  /// a timeline event on a single thread will be formed and completed before
  /// another timeline event on the same thread begins.
  @visibleForTesting
  final currentDurationEventNodes = <int, SyncTimelineEvent?>{};

  /// The previously handled DurationEnd events for each thread.
  ///
  /// We need this information to balance the tree structures of our event nodes
  /// if they fall out of balance due to duplicate trace events.
  ///
  /// Bug tracking dupes: https://github.com/flutter/flutter/issues/47020.
  final _previousDurationEndEvents = <int, TraceEvent>{};

  /// Pending root duration complete event that has not yet been added to the
  /// timeline.
  ///
  /// A DC event is a root if we do not have a current duration event tracked
  /// for the given thread.
  ///
  /// We keep this event around to avoid prematurely adding a root DC event to
  /// the timeline. Once we have processed events beyond a DC event's end
  /// timestamp, we know that the DC event has no more unprocessed children.
  /// This is guaranteed because we process the events in timestamp order.
  SyncTimelineEvent? _pendingRootCompleteEvent;

  // TODO(kenz): Remove the [uiThreadId] and [rasterThreadId] once ui/raster
  //  distinction changes and frame ids are available in the engine.
  int? uiThreadId;

  int? rasterThreadId;

  /// Process the given trace events to create [TimelineEvent]s.
  ///
  /// [traceEvents] must be sorted in increasing timestamp order before calling
  /// this method.
  Future<void> processTraceEvents(
    List<TraceEventWrapper> traceEvents, {
    int startIndex = 0,
  }) async {
    resetProcessingData();

    final _traceEvents = (traceEvents.sublist(startIndex)
          // Events need to be in increasing timestamp order.
          ..sort())
        .where((event) => event.event.timestampMicros != null)
        .toList();

    for (final trace in _traceEvents) {
      performanceController.recordTrace(trace.event.json);
    }

    // At minimum, process the data in 4 batches to smooth the appearance of
    // the progress indicator.
    final batchSize = math
        .min(_defaultBatchSize, math.max(1, _traceEvents.length / 4))
        .round();

    while (_traceEventsProcessed < _traceEvents.length) {
      _processBatch(batchSize, _traceEvents);
      _progressNotifier.value = _traceEventsProcessed / _traceEvents.length;

      // Await a small delay to give the UI thread a chance to update the
      // progress indicator.
      await delayForBatchProcessing();
    }

    final idsToRemove = <String>[];
    for (var rootEvent in _asyncEventsById.values.where((e) => e.isRoot)) {
      // Do not add incomplete async trees to the timeline.
      // TODO(kenz): infer missing end times based on other end times in the
      // async event tree. Add these "repaired" events to the timeline.
      if (!rootEvent.isWellFormedDeep) continue;

      performanceController.addTimelineEvent(rootEvent);
      idsToRemove.add(rootEvent.asyncUID);
    }
    idsToRemove.forEach(_asyncEventsById.remove);

    _addPendingCompleteRootToTimeline(force: true);

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

    resetProcessingData();
  }

  void _processBatch(int batchSize, List<TraceEventWrapper> traceEvents) {
    final batchEnd =
        math.min(_traceEventsProcessed + batchSize, traceEvents.length);
    for (int i = _traceEventsProcessed; i < batchEnd; i++) {
      final eventWrapper = traceEvents[i];
      _traceEventsProcessed++;

      // TODO(kenz): stop manually setting the type once we have that data
      // from the engine.
      eventWrapper.event.type = inferEventType(eventWrapper.event);

      // Add [pendingRootCompleteEvent] to the timeline if it is ready.
      _addPendingCompleteRootToTimeline(
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
          _handleDurationBeginEvent(eventWrapper);
          break;
        case TraceEvent.durationEndPhase:
          _handleDurationEndEvent(eventWrapper);
          break;
        case TraceEvent.durationCompletePhase:
          _handleDurationCompleteEvent(eventWrapper);
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

  void _addPendingCompleteRootToTimeline({
    int? currentProcessingTime,
    bool force = false,
  }) {
    assert(currentProcessingTime != null || force);
    if (_pendingRootCompleteEvent != null &&
        (force ||
            currentProcessingTime! >
                _pendingRootCompleteEvent!.time.end!.inMicroseconds)) {
      performanceController.addTimelineEvent(_pendingRootCompleteEvent!);
      _pendingRootCompleteEvent = null;
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
        performanceController.addTimelineEvent(currentEventWithId);
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

  void _handleDurationBeginEvent(TraceEventWrapper eventWrapper) {
    final threadId = eventWrapper.event.threadId!;
    final current = currentDurationEventNodes[threadId];
    final timelineEvent = SyncTimelineEvent(eventWrapper);
    if (current != null) {
      current.addChild(timelineEvent);
    }

    if (timelineEvent.isUiFrameIdentifier) {
      (timelineEvent.root as SyncTimelineEvent)
          .uiFrameEvents
          .add(timelineEvent);
    } else if (timelineEvent.isRasterFrameIdentifier) {
      (timelineEvent.root as SyncTimelineEvent)
          .rasterFrameEvents
          .add(timelineEvent);
    }

    currentDurationEventNodes[threadId] = timelineEvent;
  }

  void _handleDurationEndEvent(TraceEventWrapper eventWrapper) {
    final TraceEvent event = eventWrapper.event;
    final eventThreadId = event.threadId!;
    final eventJson = event.json;
    SyncTimelineEvent? current = currentDurationEventNodes[eventThreadId];

    if (current == null) return;

    // If the names of [event] and [current] do not match, our event nesting is
    // off balance due to duplicate events from the engine. Balance the tree so
    // we can continue processing trace events for [current].
    if (event.name != current.name) {
      if (collectionEquals(
        eventJson,
        _previousDurationEndEvents[eventThreadId]?.json,
      )) {
        // This is a duplicate of the previous DurationEnd event we received.
        //
        // Trace example:
        // VSYNC - DurationBegin
        // Animator::BeginFrame - DurationBegin
        // ...
        // Animator::BeginFrame - DurationEnd [previousDurationEndEvent]
        // Animator::BeginFrame - DurationEnd ([event] - duplicate)
        // VSYNC - DurationEnd
        //
        debugTraceEventCallback(
          () => log(
            'Duplicate duration end event - skipping processing: $eventJson',
          ),
        );
        return;
      } else if (current.parent?.name == event.name) {
        if (current.name == _previousDurationEndEvents[eventThreadId]?.name &&
            current.children.length == 1 &&
            collectionEquals(
              current.beginTraceEventJson,
              current.children.first.beginTraceEventJson,
            )) {
          // There was a duplicate DurationBegin event associated with
          // [previousDurationEndEvent]. [event] is actually the DurationEnd event
          // for [current.parent]. Trim the extra layer created by the duplicate.
          //
          // Trace example:
          // VSYNC - DurationBegin
          // Animator::BeginFrame - DurationBegin [current] (duplicate - remove this node)
          // Animator::BeginFrame - DurationBegin
          // ...
          // Animator::BeginFrame - DurationEnd [previousDurationEndEvent]
          // VSYNC - DurationEnd [event]
          //
          debugTraceEventCallback(
            () => log(
              'Duplicate duration begin event - removing duplicate:'
              ' ${current?.beginTraceEventJson}',
            ),
          );

          current.parent!.removeChild(current);
          current = current.parent as SyncTimelineEvent?;
          currentDurationEventNodes[eventThreadId] = current;
        } else {
          // We have a valid begin event that is missing a matching end event.
          // Create a fake end event to re-balance the tree.
          //
          // Trace example:
          // VSYNC - DurationBegin
          // BUILD - DurationBegin [current] (missing a matching end event)
          // Animator::BeginFrame - DurationBegin
          // ...
          // Animator::BeginFrame - DurationEnd [previousDurationEndEvent]
          // <this is where the DurationEnd BUILD event should be>
          // VSYNC - DurationEnd [event]
          //
          final currentBeginTrace = current.traceEvents.first.event;

          // For the fake end timestamp, split the difference between the end
          // time of the last child of [current] and the end time of the [event]
          // we are currently trying to process. Or, if [current] has no
          // children, use the end timestamp [event] with a small buffer to
          // ensure the fake event ends before the [event].
          final lastChildOfCurrentEndTime = current
              .children.safeLast?.endTraceEventJson?[TraceEvent.timestampKey];
          final eventEndTime = event.timestampMicros!;
          const fakeEndEventTimeBuffer = 1;
          final fakeTimestampMicros = lastChildOfCurrentEndTime != null
              ? eventEndTime -
                  ((eventEndTime - lastChildOfCurrentEndTime) / 2).round()
              : eventEndTime - fakeEndEventTimeBuffer;

          final fakeEndEvent = TraceEventWrapper(
            currentBeginTrace.copy(
              phase: TraceEvent.durationEndPhase,
              timestampMicros: fakeTimestampMicros,
              args: {
                'message': 'Warning - the end time of this event may be '
                    'innacurate. The end trace event was missing, so the end '
                    'time was inferred.',
              },
            ),
            // Use the same time received as the current event we are trying to
            // process.
            eventWrapper.timeReceived,
          );

          debugTraceEventCallback(() {
            log(
              'Missing DurationEnd event - adding fake end event $fakeEndEvent',
            );
          });

          current.addEndEvent(fakeEndEvent);
          current = current.parent as SyncTimelineEvent?;

          // Do not return early. Now that the tree is rebalanced, we can
          // continue processing [event].
          assert(current != null && event.name != current.name);
        }
      } else {
        // The current event node has fallen into an unrecoverable state. Reset
        // the tracking node.
        //
        // Trace example:
        // VSYNC - DurationBegin
        //  Animator::BeginFrame - DurationBegin
        //   VSYNC - DurationBegin (duplicate)
        //    Animator::BeginFrame - DurationBegin (duplicate)
        //     ...
        //  Animator::BeginFrame - DurationEnd
        // VSYNC - DurationEnd
        debugTraceEventCallback(() {
          log('Cannot recover unbalanced event tree.');
          log('Event: $eventJson');
          log('Current: $current');
        });
        currentDurationEventNodes[eventThreadId] = null;
        return;
      }
    }

    _previousDurationEndEvents[eventThreadId] = event;

    current!.addEndEvent(eventWrapper);

    // Even if the event is well nested, we could still have a duplicate in the
    // tree that needs to be removed. Ex:
    //   VSYNC - StartTime 123
    //      VSYNC - StartTime 123 (duplicate)
    //      VSYNC - EndTime 234 (duplicate)
    //   VSYNC - EndTime 234
    current.maybeRemoveDuplicate();

    // Since this event is complete, move back up the tree to the nearest
    // incomplete event.
    while (current!.parent != null &&
        current.parent!.time.end?.inMicroseconds != null) {
      current = current.parent as SyncTimelineEvent?;
    }
    currentDurationEventNodes[eventThreadId] =
        current.parent as SyncTimelineEvent?;

    // If we have reached a null parent, this event is fully formed - add it to
    // the timeline and try to assign it to a Flutter frame.
    if (current.parent == null) {
      performanceController.addTimelineEvent(current);
    }
  }

  void _handleDurationCompleteEvent(TraceEventWrapper eventWrapper) {
    final event = eventWrapper.event;
    final timelineEvent = SyncTimelineEvent(eventWrapper)
      ..time.end =
          Duration(microseconds: event.timestampMicros! + event.duration!);

    final current = currentDurationEventNodes[event.threadId];
    if (current != null) {
      if (current.subtreeHasNodeWithCondition(
        (TimelineEvent event) => collectionEquals(
          event.beginTraceEventJson,
          timelineEvent.beginTraceEventJson,
        ),
      )) {
        // This is a duplicate DurationComplete event. Return early.
        return;
      }
      current.addChild(timelineEvent);
    } else {
      // Since we do not have a current duration event for this thread, this DC
      // event is either a timeline root event or a child of
      // [pendingRootCompleteEvent].
      if (_pendingRootCompleteEvent == null) {
        _pendingRootCompleteEvent = timelineEvent;
      } else {
        _pendingRootCompleteEvent!.addChild(timelineEvent);
      }
    }
  }

  void reset() {
    _asyncEventsById.clear();
    currentDurationEventNodes.clear();
    _previousDurationEndEvents.clear();
    _pendingRootCompleteEvent = null;
    resetProcessingData();
  }

  void resetProcessingData() {
    _traceEventsProcessed = 0;
    _progressNotifier.value = 0.0;
  }

  void primeThreadIds({
    required int? uiThreadId,
    required int? rasterThreadId,
  }) {
    this.uiThreadId = uiThreadId;
    this.rasterThreadId = rasterThreadId;
  }

  @visibleForTesting
  TimelineEventType inferEventType(TraceEvent event) {
    if (event.phase == TraceEvent.asyncBeginPhase ||
        event.phase == TraceEvent.asyncInstantPhase ||
        event.phase == TraceEvent.asyncEndPhase) {
      return TimelineEventType.async;
    } else if (event.threadId != null && event.threadId == uiThreadId) {
      return TimelineEventType.ui;
    } else if (event.threadId != null && event.threadId == rasterThreadId) {
      return TimelineEventType.raster;
    } else {
      return TimelineEventType.other;
    }
  }
}
