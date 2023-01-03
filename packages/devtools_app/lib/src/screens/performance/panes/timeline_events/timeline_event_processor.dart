// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/config_specific/logger/logger.dart';
import '../../../../shared/primitives/trace_event.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_controller.dart';
import '../../performance_model.dart';
import '../../performance_utils.dart';
import 'timeline_events_controller.dart';

// For documentation on the Chrome "Trace Event Format", see this document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview
// This class depends on the stability of event names we receive from the
// engine. That dependency is tracked at
// https://github.com/flutter/flutter/issues/27609.

const String rasterEventName = 'GPURasterizer::Draw';

const String rasterEventNameWithFrameNumber = 'Rasterizer::DoDraw';

const String uiEventName = 'Animator::BeginFrame';

abstract class BaseTraceEventProcessor {
  BaseTraceEventProcessor(this.performanceController);

  final PerformanceController performanceController;

  TimelineEventsController get eventsController =>
      performanceController.timelineEventsController;

  int? uiThreadId;

  int? rasterThreadId;

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

  /// Process the given trace events to create [TimelineEvent]s.
  ///
  /// [traceEvents] must be sorted in increasing timestamp order before calling
  /// this method.
  FutureOr<void> processData(
    List<TraceEventWrapper> traceEvents, {
    int startIndex = 0,
  }) async {
    // Events need to be in increasing timestamp order.
    final _traceEvents = traceEvents.sublist(startIndex)..sort();

    // A subclass of [BaseTimelineEventProcessor] must implement this method.
    await processTraceEvents(_traceEvents);

    addPendingCompleteRootToTimeline(force: true);

    // Perform any necessary post-processing on the data. A suclass of
    // [BaseTimelineEventProcessor] should override [postProcessTraceEvents] if
    // the subclass needs to perform post-processing.
    postProcessData();
  }

  @protected
  FutureOr<void> processTraceEvents(List<TraceEventWrapper> events);

  @protected
  void postProcessData() {}

  @protected
  void handleDurationBeginEvent(TraceEventWrapper eventWrapper) {
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

  @protected
  void handleDurationEndEvent(TraceEventWrapper eventWrapper) {
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
      eventsController.addTimelineEvent(current);
    }
  }

  @protected
  void handleDurationCompleteEvent(TraceEventWrapper eventWrapper) {
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

  @protected
  void addPendingCompleteRootToTimeline({
    int? currentProcessingTime,
    bool force = false,
  }) {
    assert(currentProcessingTime != null || force);
    if (_pendingRootCompleteEvent != null &&
        (force ||
            currentProcessingTime! >
                _pendingRootCompleteEvent!.time.end!.inMicroseconds)) {
      eventsController.addTimelineEvent(_pendingRootCompleteEvent!);
      _pendingRootCompleteEvent = null;
    }
  }

  void reset() {
    currentDurationEventNodes.clear();
    _previousDurationEndEvents.clear();
    _pendingRootCompleteEvent = null;
  }

  void primeThreadIds({
    required int? uiThreadId,
    required int? rasterThreadId,
  }) {
    this.uiThreadId = uiThreadId;
    this.rasterThreadId = rasterThreadId;
  }

  @visibleForTesting
  @protected
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
