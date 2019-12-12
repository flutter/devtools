// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../utils.dart';
//import 'simple_trace_example.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

// For documentation, see the Chrome "Trace Event Format" document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU.
// This class depends on the stability of event names we receive from the
// engine. That dependency is tracked at
// https://github.com/flutter/flutter/issues/27609.

/// Switch this flag to true collect debug info from the timeline protocol.
///
/// This will add a button to the timeline page that will download files with
/// debug info on click.
bool debugTimeline = false;

/// List that will store trace event json in the order we handle the events.
///
/// This list is for debug purposes. When [debugTimeline] is true, we will be
/// able to dump this data to a downloadable text file.
List<Map<String, dynamic>> debugHandledTraceEvents = [];

/// Buffer that will store significant events in the frame tracking process.
///
/// This buffer is for debug purposes. When [debugTimeline] is true, we will
/// be able to dump this buffer to a downloadable text file.
StringBuffer debugFrameTracking = StringBuffer();

/// Epsilon in micros used for determining it an event fits within a given frame
/// boundary.
///
/// This epsilon will not be used if the duration of the event is less than 2000
/// micros (2 ms). We do this to hold a requirement that at least half of the
/// event must fit within the frame boundaries.
const Duration traceEventEpsilon = Duration(microseconds: 1000);

/// Delay in ms for processing trace events.
const Duration traceEventDelay = Duration(milliseconds: 1000);

const String gpuEventName = 'GPURasterizer::Draw';

const String uiEventName = 'VSYNC';

/// Protocol for processing trace events and composing them into
/// [SyncTimelineEvents] and [TimelineFrames].
class FrameBasedTimelineProcessor extends TimelineProcessor {
  FrameBasedTimelineProcessor({
    @required int uiThreadId,
    @required int gpuThreadId,
    @required TimelineController timelineController,
  }) : super(
          uiThreadId: uiThreadId,
          gpuThreadId: gpuThreadId,
          timelineController: timelineController,
        );

  /// Frames we are in the process of assembling.
  ///
  /// Once frames are ready, we will remove them from this Map and add them to
  /// the timeline.
  final Map<String, TimelineFrame> pendingFrames = <String, TimelineFrame>{};

  /// Events we have collected and are waiting to add to their respective
  /// frames.
  final List<SyncTimelineEvent> pendingEvents = [];

  /// The current nodes in the tree structures of UI and GPU duration events.
  final List<SyncTimelineEvent> currentEventNodes = [null, null];

  /// The previously handled DurationEnd events for both UI and GPU.
  ///
  /// We need this information to balance the tree structures of our event nodes
  /// if they fall out of balance due to duplicate trace events.
  final List<TraceEvent> _previousDurationEndEvents = [null, null];

  /// Heaps that order and store trace events as we receive them.
  final heaps = List.generate(
    2,
    (_) => HeapPriorityQueue<TraceEventWrapper>(),
  );

  void processTraceEvent(
    TraceEventWrapper eventWrapper, {
    bool immediate = false,
  }) {
    final event = eventWrapper.event;
    // TODO(kenz): stop manually setting the type once we have that data from
    // the engine.
    event.type = inferEventType(event);

    if (!_shouldProcessTraceEvent(event)) return;

    // Process flow events now. Process Duration events after a delay. Only
    // process flow events whose name is PipelineItem, as these events mark the
    // start and end for a frame. Processing other types of flow events would
    // lead to us creating Timeline frames where we shouldn't and therefore
    // showing bad data to the user.
    switch (event.phase) {
      case TraceEvent.flowStartPhase:
        if (event.name.contains('PipelineItem')) {
          _handleFrameStartEvent(event);
        }
        break;
      case TraceEvent.flowEndPhase:
        if (event.name.contains('PipelineItem')) {
          _handleFrameEndEvent(event);
        }
        break;
      default:
        if (immediate) {
          _processDurationEvent(eventWrapper);
        } else {
          // Add trace event to respective heap.
          final heap = heaps[event.type.index];

          // Create a new [TraceEventWrapper] so that the delay starts now.
          heap.add(TraceEventWrapper(
            event,
            DateTime.now().millisecondsSinceEpoch,
          ));
          // Process duration events with a delay.
          executeWithDelay(
            Duration(milliseconds: traceEventDelay.inMilliseconds),
            () => _processDurationEvents(heap),
            executeNow: _shouldProcessTopEvent(heap),
          );
        }
    }
  }

  bool _shouldProcessTopEvent(HeapPriorityQueue<TraceEventWrapper> heap) {
    return heap.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch - heap.first.timeReceived >=
            traceEventDelay.inMilliseconds;
  }

  void _processDurationEvents(HeapPriorityQueue<TraceEventWrapper> heap) {
    while (heap.isNotEmpty && _shouldProcessTopEvent(heap)) {
      _processDurationEvent(heap.removeFirst());
    }
  }

  void _processDurationEvent(TraceEventWrapper eventWrapper) {
    final TraceEvent event = eventWrapper.event;

    // We may get a stray event whose timestamp is out of bounds of our current
    // event node. Do not process these events.
    if (currentEventNodes[event.type.index] != null &&
        event.timestampMicros <
            currentEventNodes[event.type.index]
                .root
                .time
                .start
                .inMicroseconds) {
      return;
    }

    if (debugTimeline) {
      debugHandledTraceEvents.add(event.json);
      debugFrameTracking.writeln('Handling - ${event.json}');
    }

    switch (event.phase) {
      case TraceEvent.durationBeginPhase:
        _handleDurationBeginEvent(eventWrapper);
        break;
      case TraceEvent.durationEndPhase:
        _handleDurationEndEvent(eventWrapper);
        break;
      case TraceEvent.durationCompletePhase:
        _handleDurationCompleteEvent(eventWrapper);
        break;
      // We do not need to handle other event types (phases 'b', 'n', 'e', etc.)
      // because UI/GPU work will take place in DurationEvents.
    }

    if (debugTimeline) {
      debugFrameTracking.writeln('After Handling:');
      currentEventNodes[event.type.index]
          ?.formatFromRoot(debugFrameTracking, '  ');
    }
  }

  void _handleFrameStartEvent(TraceEvent event) {
    if (event.id != null) {
      final String id = _getFrameId(event);
      final pendingFrame =
          pendingFrames.putIfAbsent(id, () => TimelineFrame(id));

      pendingFrame.pipelineItemTime.start = Duration(
        microseconds: nullSafeMin(
          pendingFrame.pipelineItemTime.start?.inMicroseconds,
          event.timestampMicros,
        ),
      );

      if (pendingFrame.pipelineItemTime.start.inMicroseconds ==
          event.timestampMicros) {
        pendingFrame.pipelineItemStartTrace = event;
      }

      if (debugTimeline) {
        debugHandledTraceEvents.add(event.json);
        debugFrameTracking.writeln('Frame Start: $id - ${event.json}');
      }

      maybeAddPendingEvents();
    }
  }

  void _handleFrameEndEvent(TraceEvent event) async {
    if (event.id != null) {
      final String id = _getFrameId(event);
      final pendingFrame =
          pendingFrames.putIfAbsent(id, () => TimelineFrame(id));

      pendingFrame.pipelineItemTime.end = Duration(
        microseconds: nullSafeMax(
          pendingFrame.pipelineItemTime.end?.inMicroseconds,
          event.timestampMicros,
        ),
      );

      if (pendingFrame.pipelineItemTime.end.inMicroseconds ==
          event.timestampMicros) {
        pendingFrame.pipelineItemEndTrace = event;
      }

      if (debugTimeline) {
        debugHandledTraceEvents.add(event.json);
        debugFrameTracking.writeln('Frame End: $id');
      }

      maybeAddPendingEvents();
    }
  }

  String _getFrameId(TraceEvent event) {
    return '${event.name}-${event.id}';
  }

  void _handleDurationBeginEvent(TraceEventWrapper eventWrapper) {
    final TraceEvent event = eventWrapper.event;
    final current = currentEventNodes[event.type.index];
    if (current == null &&
        !(event.name.contains(uiEventName) ||
            event.name.contains(gpuEventName))) {
      return;
    }

    final timelineEvent = SyncTimelineEvent(eventWrapper);

    if (current != null) {
      current.addChild(timelineEvent);
    }
    currentEventNodes[event.type.index] = timelineEvent;
  }

  void _handleDurationEndEvent(TraceEventWrapper eventWrapper) {
    final TraceEvent event = eventWrapper.event;
    SyncTimelineEvent current = currentEventNodes[event.type.index];

    if (current == null) return;

    // If the names of [event] and [current] do not match, our event nesting is
    // off balance due to duplicate events from the engine. Balance the tree so
    // we can continue processing trace events for [current].
    if (event.name != current.name) {
      if (collectionEquals(
        event.json,
        _previousDurationEndEvents[event.type.index]?.json,
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
        if (debugTimeline) {
          debugFrameTracking
              .writeln('Duplicate duration end event: ${event.json}');
        }
        return;
      } else if (current.name ==
              _previousDurationEndEvents[event.type.index]?.name &&
          current.parent?.name == event.name &&
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
        // Animator::BeginFrame - DurationBegin (duplicate - remove this node)
        // Animator::BeginFrame - DurationBegin
        // ...
        // Animator::BeginFrame - DurationEnd [previousDurationEndEvent]
        // VSYNC - DurationEnd [event]
        //
        if (debugTimeline) {
          debugFrameTracking.writeln(
              'Duplicate duration begin event: ${current.beginTraceEventJson}');
        }

        current.parent.removeChild(current);
        current = current.parent;
        currentEventNodes[event.type.index] = current;
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
        if (debugTimeline) {
          debugFrameTracking.writeln('Cannot recover unbalanced event tree.');
          debugFrameTracking.writeln('Event: ${event.json}');
          debugFrameTracking
              .writeln('Current: ${currentEventNodes[event.type.index]}');
        }
        currentEventNodes[event.type.index] = null;
        return;
      }
    }

    _previousDurationEndEvents[event.type.index] = event;

    current.addEndEvent(eventWrapper);

    // Even if the event is well nested, we could still have a duplicate in the
    // tree that needs to be removed. Ex:
    //   VSYNC - StartTime 123
    //      VSYNC - StartTime 123 (duplicate)
    //      VSYNC - EndTime 234 (duplicate)
    //   VSYNC - EndTime 234
    current.maybeRemoveDuplicate();

    // Since this event is complete, move back up the tree to the nearest
    // incomplete event.
    while (current.parent != null &&
        current.parent.time.end?.inMicroseconds != null) {
      current = current.parent;
    }
    currentEventNodes[event.type.index] = current.parent;

    // If we have reached a null parent, this event is fully formed.
    if (current.parent == null) {
      if (debugTimeline) {
        debugFrameTracking.writeln('Trying to add event after DurationEnd:');
        current.format(debugFrameTracking, '   ');
      }
      _maybeAddEvent(current);
    }
  }

  void _handleDurationCompleteEvent(TraceEventWrapper eventWrapper) {
    final TraceEvent event = eventWrapper.event;
    final timelineEvent = SyncTimelineEvent(eventWrapper);

    timelineEvent.time.end =
        Duration(microseconds: event.timestampMicros + event.duration);

    final current = currentEventNodes[event.type.index];
    if (current != null) {
      if (current
          .containsChildWithCondition((TimelineEvent event) => collectionEquals(
                event.beginTraceEventJson,
                timelineEvent.beginTraceEventJson,
              ))) {
        // This is a duplicate DurationComplete event. Return early.
        return;
      }
      current.addChild(timelineEvent);
    } else {
      _maybeAddEvent(timelineEvent);
    }
  }

  /// Looks through [pendingEvents] and attempts to add events to frames in
  /// [pendingFrames].
  void maybeAddPendingEvents() {
    if (pendingEvents.isEmpty || pendingFrames.isEmpty) return;

    // Sort _pendingEvents by their startTime. This ensures we will add the
    // first matching event within the time boundary to the frame.
    pendingEvents.sort((SyncTimelineEvent a, SyncTimelineEvent b) {
      return a.time.start.inMicroseconds.compareTo(b.time.start.inMicroseconds);
    });

    final List<TimelineFrame> frames = _getAndSortWellFormedFrames();
    for (TimelineFrame frame in frames) {
      final eventsToRemove = [];

      for (var event in pendingEvents) {
        final bool eventAdded = _maybeAddEventToFrame(event, frame);
        if (eventAdded) {
          eventsToRemove.add(event);
          break;
        }
      }

      if (eventsToRemove.isNotEmpty) {
        eventsToRemove.forEach(pendingEvents.remove);
      }
    }
  }

  /// Add event to an available frame in [pendingFrames] if we can, or
  /// otherwise add it to [pendingEvents].
  void _maybeAddEvent(SyncTimelineEvent event) {
    if (!event.isUiEventFlow && !event.isGpuEventFlow) {
      // We do not care about events that are neither the main flow of UI
      // events nor the main flow of GPU events.
      return;
    }

    bool eventAdded = false;

    final List<TimelineFrame> frames = _getAndSortWellFormedFrames();
    for (TimelineFrame frame in frames) {
      eventAdded = _maybeAddEventToFrame(event, frame);
      if (eventAdded) {
        maybeAddPendingEvents();
        break;
      }
    }

    if (!eventAdded) {
      if (debugTimeline) {
        debugFrameTracking.writeln('Adding event [${event.name}: '
            '${event.time.start.inMicroseconds} - '
            '${event.time.end?.inMicroseconds}] to pendingEvents');
      }
      pendingEvents.add(event);
    }
  }

  /// Attempts to add [event] to [frame], and returns a bool indicating whether
  /// the attempt was successful.
  bool _maybeAddEventToFrame(SyncTimelineEvent event, TimelineFrame frame) {
    // Ensure the frame does not already have an event of this type and that
    // the event fits within the frame's time boundaries.
    if (frame.eventFlows[event.type.index] != null ||
        !eventOccursWithinFrameBounds(event, frame)) {
      return false;
    }

    frame.setEventFlow(event);

    if (debugTimeline) {
      debugFrameTracking.writeln(
          'Adding event [${event.name}: ${event.time.start.inMicroseconds} '
          '- ${event.time.end?.inMicroseconds}] to frame ${frame.id}');
    }

    // Adding event [e] could mean we have completed the frame. Check if we
    // should add the completed frame to [_frameCompleteController].
    _maybeAddCompletedFrame(frame);

    return true;
  }

  void _maybeAddCompletedFrame(TimelineFrame frame) {
    if (frame.isReadyForTimeline && frame.addedToTimeline == null) {
      if (debugTimeline) {
        debugFrameTracking.writeln('Completing ${frame.id}');
      }

      // Record the trace events for this timeline frame.
      timelineController.recordTrace(frame.pipelineItemStartTrace.json);
      timelineController.recordTraceForTimelineEvent(frame.uiEventFlow);
      timelineController.recordTraceForTimelineEvent(frame.gpuEventFlow);
      timelineController.recordTrace(frame.pipelineItemEndTrace.json);

      timelineController.frameBasedTimeline.addFrame(frame);
      pendingFrames.remove(frame.id);
      frame.addedToTimeline = true;

      // TODO(kenz): add cpu profile pre-fetching here when the app is idle.
    }
  }

  @visibleForTesting
  bool eventOccursWithinFrameBounds(SyncTimelineEvent e, TimelineFrame f) {
    // TODO(kenz): talk to the engine team about why we need the epsilon. Why
    // do event times extend slightly beyond the times we get from frame start
    // and end flow events.

    // Epsilon in microseconds. If more than half of the event fits in bounds,
    // then we consider the event as fitting. If the event has a large duration,
    // consider it as fitting if it fits within [traceEventEpsilon] micros of
    // the frame bound.
    final int epsilon = min(
      e.time.duration.inMicroseconds ~/ 2,
      traceEventEpsilon.inMicroseconds,
    );

    assert(f.pipelineItemTime.start != null);
    assert(f.pipelineItemTime.end != null);

    // Allow the event to extend the frame boundaries by [epsilon] microseconds.
    final bool fitsStartBoundary = f.pipelineItemTime.start.inMicroseconds -
            e.time.start.inMicroseconds -
            epsilon <=
        0;
    final bool fitsEndBoundary = f.pipelineItemTime.end.inMicroseconds -
            e.time.end?.inMicroseconds +
            epsilon >=
        0;

    // The [gpuEventFlow] should always start after the [uiEventFlow].
    bool satisfiesUiGpuOrder() {
      if (e.isUiEventFlow && f.gpuEventFlow != null) {
        return e.time.start.inMicroseconds <
            f.gpuEventFlow.time.start.inMicroseconds;
      } else if (e.isGpuEventFlow && f.uiEventFlow != null) {
        return e.time.start.inMicroseconds >
            f.uiEventFlow.time.start.inMicroseconds;
      }
      // We do not have enough information about the frame to compare UI and
      // GPU start times, so return true.
      return true;
    }

    return fitsStartBoundary && fitsEndBoundary && satisfiesUiGpuOrder();
  }

  List<TimelineFrame> _getAndSortWellFormedFrames() {
    final List<TimelineFrame> frames = pendingFrames.values
        .where((TimelineFrame frame) => frame.isWellFormed)
        .toList();

    // Sort frames by their startTime. Sorting these frames ensures we will
    // handle the oldest frame first when iterating through the list.
    frames.sort((TimelineFrame a, TimelineFrame b) {
      return a.pipelineItemTime.start.inMicroseconds
          .compareTo(b.pipelineItemTime.start.inMicroseconds);
    });

    return frames;
  }

  bool _shouldProcessTraceEvent(TraceEvent event) {
    final phaseWhitelist = {
      TraceEvent.flowStartPhase,
      TraceEvent.flowEndPhase,
      TraceEvent.durationBeginPhase,
      TraceEvent.durationEndPhase,
      TraceEvent.durationCompletePhase,
    };
    return phaseWhitelist.contains(event.phase) &&
        // Do not process Garbage Collection events.
        event.category != 'GC' &&
        // Do not process MessageLoop::RunExpiredTasks events. These events can
        // either a) start outside of our frame start time, b) parent irrelevant
        // events, or c) parent multiple event flows - none of which we want.
        event.name != 'MessageLoop::RunExpiredTasks' &&
        // Only process events from the UI or GPU thread.
        (event.isGpuEvent || event.isUiEvent);
  }

  @override
  void reset() {
    pendingFrames.clear();
    pendingEvents.clear();
    for (var heap in heaps) {
      heap.clear();
    }
    // Reset initial states.
    currentEventNodes
      ..clear()
      ..addAll([null, null]);
    _previousDurationEndEvents
      ..clear()
      ..addAll([null, null]);
  }
}

/// Processor for composing a recorded list of trace events into a timeline of
/// [AsyncTimelineEvent]s and [SyncTimelineEvent]s.
class FullTimelineProcessor extends TimelineProcessor {
  FullTimelineProcessor({
    @required int uiThreadId,
    @required int gpuThreadId,
    @required TimelineController timelineController,
  }) : super(
          uiThreadId: uiThreadId,
          gpuThreadId: gpuThreadId,
          timelineController: timelineController,
        );

  /// Async timeline events we have processed, mapped to their respective async
  /// ids.
  Map<String, AsyncTimelineEvent> asyncEventsById = {};

  /// The current timeline event nodes for duration events.
  ///
  /// The events are mapped to their thread id. As we process duration events,
  /// a timeline event on a single thread will be formed and completed before
  /// another timeline event on the same thread begins.
  final Map<int, SyncTimelineEvent> currentDurationEventNodes = {};

  /// The previously handled DurationEnd events for each thread.
  ///
  /// We need this information to balance the tree structures of our event nodes
  /// if they fall out of balance due to duplicate trace events.
  final Map<int, TraceEvent> previousDurationEndEvents = {};

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
  SyncTimelineEvent pendingRootCompleteEvent;

  void processTimeline(List<TraceEventWrapper> traceEvents) async {
// Uncomment this code for testing the timeline.
//    traceEvents = simpleTraceEvents['traceEvents']
//        .where((json) =>
//            json.containsKey(TraceEvent.timestampKey)) // thread_name events
//        .map((e) => TraceEventWrapper(
//            TraceEvent(e), DateTime.now().microsecondsSinceEpoch))
//        .toList();
    final _traceEvents = (traceEvents
        // Throw out timeline events that do not have a timestamp
        // (e.g. thread_name events).
        .where((event) => event.event.timestampMicros != null)
        .toList())
      // Events need to be in increasing timestamp order.
      ..sort()
      ..map((event) => event.event.json)
          .toList()
          .forEach(timelineController.recordTrace);

    for (var eventWrapper in _traceEvents) {
      // TODO(kenz): stop manually setting the type once we have that data
      // from the engine.
      eventWrapper.event.type = inferEventType(eventWrapper.event);

      // Add [pendingRootCompleteEvent] to the timeline if it is ready.
      _addPendingCompleteRootToTimeline(
          currentProcessingTime: eventWrapper.event.timestampMicros);

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
        case TraceEvent.flowStartPhase:
        case TraceEvent.flowEndPhase:
        // TODO(kenz): add support for flows.
        default:
          break;
      }
    }

    for (var rootEvent in asyncEventsById.values.where((e) => e.isRoot)) {
      // Do not add incomplete async trees to the timeline.
      // TODO(kenz): infer missing end times based on other end times in the
      // async event tree. Add these "repaired" events to the timeline.
      if (!rootEvent.isWellFormedDeep) continue;

      timelineController.fullTimeline.addTimelineEvent(rootEvent);
    }

    _addPendingCompleteRootToTimeline(force: true);

    timelineController.fullTimeline.data.time
      // We process trace events in timestamp order, so we can ensure the first
      // trace event has the earliest starting timestamp.
      ..start = Duration(microseconds: _traceEvents.first.event.timestampMicros)
      // We cannot guarantee that the last trace event is the latest timestamp
      // in the timeline. DurationComplete events' timestamps refer to their
      // starting timestamp, but their end time is derived from the same trace
      // via the "dur" field. For this reason, we use the cached value stored in
      // [timelineController.fullTimeline].
      ..end = Duration(
          microseconds:
              timelineController.fullTimeline.data.endTimestampMicros);
  }

  void _addPendingCompleteRootToTimeline({
    int currentProcessingTime,
    bool force = false,
  }) {
    assert(currentProcessingTime != null || force);
    if (pendingRootCompleteEvent != null &&
        (force ||
            currentProcessingTime >
                pendingRootCompleteEvent.time.end.inMicroseconds)) {
      timelineController.fullTimeline
          .addTimelineEvent(pendingRootCompleteEvent);
      pendingRootCompleteEvent = null;
    }
  }

  void _addAsyncEvent(TraceEventWrapper eventWrapper) {
    final timelineEvent = AsyncTimelineEvent(eventWrapper);
    if (eventWrapper.event.phase == TraceEvent.asyncInstantPhase) {
      timelineEvent.time.end = timelineEvent.time.start;
    }

    // If parentId is specified, use it to define the async tree structure.
    final parentId = timelineEvent.parentId;
    if (parentId != null) {
      final parent = asyncEventsById[parentId];
      if (parent != null) {
        parent.addChild(timelineEvent);
      }
      asyncEventsById[eventWrapper.event.id] = timelineEvent;
      return;
    }

    final currentEventWithId = asyncEventsById[eventWrapper.event.id];

    // If we already have a timeline event with the same async id as
    // [timelineEvent] (e.g. [currentEventWithId]), then [timelineEvent] is
    // either a child of [currentEventWithId] or a new root event with this id.
    if (currentEventWithId != null) {
      if (currentEventWithId.isWellFormedDeep) {
        // [timelineEvent] is a new root with the same id as
        // [currentEventWithId]. Since [currentEventWithId] is well formed, add
        // it to the timeline.
        timelineController.fullTimeline.addTimelineEvent(currentEventWithId);
        asyncEventsById[eventWrapper.event.id] = timelineEvent;
      } else {
        assert(
          !currentEventWithId.isWellFormed,
          'Event with id ${eventWrapper.event.id} is not well formed. '
          'Event trace: ${eventWrapper.event}',
        );
        // We know it must be a child because we process events in timestamp
        // order.
        currentEventWithId.addChild(timelineEvent);
      }
    } else {
      asyncEventsById[eventWrapper.event.id] = timelineEvent;
    }
  }

  void _endAsyncEvent(TraceEventWrapper eventWrapper) {
    final root = asyncEventsById[eventWrapper.event.id];
    if (root == null) {
      // Since we process trace events in timestamp order, we can guarantee that
      // we have not already processed the matching begin event. Discard the end
      // event in this case.
      return;
    }
    root.endAsyncEvent(eventWrapper);
  }

  void _handleDurationBeginEvent(TraceEventWrapper eventWrapper) {
    final current = currentDurationEventNodes[eventWrapper.event.threadId];
    final timelineEvent = SyncTimelineEvent(eventWrapper);
    if (current != null) {
      current.addChild(timelineEvent);
    }
    currentDurationEventNodes[eventWrapper.event.threadId] = timelineEvent;
  }

  void _handleDurationEndEvent(TraceEventWrapper eventWrapper) {
    final TraceEvent event = eventWrapper.event;
    SyncTimelineEvent current = currentDurationEventNodes[event.threadId];

    if (current == null) return;

    // If the names of [event] and [current] do not match, our event nesting is
    // off balance due to duplicate events from the engine. Balance the tree so
    // we can continue processing trace events for [current].
    if (event.name != current.name) {
      if (collectionEquals(
        event.json,
        previousDurationEndEvents[event.threadId]?.json,
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
        if (debugTimeline) {
          debugFrameTracking
              .writeln('Duplicate duration end event: ${event.json}');
        }
        return;
      } else if (current.name ==
              previousDurationEndEvents[event.threadId]?.name &&
          current.parent?.name == event.name &&
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
        // Animator::BeginFrame - DurationBegin (duplicate - remove this node)
        // Animator::BeginFrame - DurationBegin
        // ...
        // Animator::BeginFrame - DurationEnd [previousDurationEndEvent]
        // VSYNC - DurationEnd [event]
        //
        if (debugTimeline) {
          debugFrameTracking.writeln(
              'Duplicate duration begin event: ${current.beginTraceEventJson}');
        }

        current.parent.removeChild(current);
        current = current.parent;
        currentDurationEventNodes[event.threadId] = current;
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
        if (debugTimeline) {
          debugFrameTracking.writeln('Cannot recover unbalanced event tree.');
          debugFrameTracking.writeln('Event: ${event.json}');
          debugFrameTracking
              .writeln('Current: ${currentDurationEventNodes[event.threadId]}');
        }
        currentDurationEventNodes[event.threadId] = null;
        return;
      }
    }

    previousDurationEndEvents[event.threadId] = event;

    current.addEndEvent(eventWrapper);

    // Even if the event is well nested, we could still have a duplicate in the
    // tree that needs to be removed. Ex:
    //   VSYNC - StartTime 123
    //      VSYNC - StartTime 123 (duplicate)
    //      VSYNC - EndTime 234 (duplicate)
    //   VSYNC - EndTime 234
    current.maybeRemoveDuplicate();

    // Since this event is complete, move back up the tree to the nearest
    // incomplete event.
    while (current.parent != null &&
        current.parent.time.end?.inMicroseconds != null) {
      current = current.parent;
    }
    currentDurationEventNodes[event.threadId] = current.parent;

    // If we have reached a null parent, this event is fully formed.
    if (current.parent == null) {
      if (debugTimeline) {
        debugFrameTracking.writeln('Trying to add event after DurationEnd:');
        current.format(debugFrameTracking, '   ');
      }
      timelineController.fullTimeline.addTimelineEvent(current);
    }
  }

  void _handleDurationCompleteEvent(TraceEventWrapper eventWrapper) {
    final event = eventWrapper.event;
    final timelineEvent = SyncTimelineEvent(eventWrapper)
      ..time.end =
          Duration(microseconds: event.timestampMicros + event.duration);

    final current = currentDurationEventNodes[event.threadId];
    if (current != null) {
      if (current
          .containsChildWithCondition((TimelineEvent event) => collectionEquals(
                event.beginTraceEventJson,
                timelineEvent.beginTraceEventJson,
              ))) {
        // This is a duplicate DurationComplete event. Return early.
        return;
      }
      current.addChild(timelineEvent);
    } else {
      // Since we do not have a current duration event for this thread, this DC
      // event is either a timeline root event or a child of
      // [pendingRootCompleteEvent].
      if (pendingRootCompleteEvent == null) {
        pendingRootCompleteEvent = timelineEvent;
      } else {
        pendingRootCompleteEvent.addChild(timelineEvent);
      }
    }
  }

  @override
  void reset() {
    asyncEventsById.clear();
    currentDurationEventNodes.clear();
    previousDurationEndEvents.clear();
    pendingRootCompleteEvent = null;
  }
}

abstract class TimelineProcessor {
  TimelineProcessor({
    @required this.uiThreadId,
    @required this.gpuThreadId,
    @required this.timelineController,
  });

  // TODO(kenz): Remove the [uiThreadId] and [gpuThreadId] once ui/gpu
  //  distinction changes and frame ids are available in the engine.
  final int uiThreadId;

  final int gpuThreadId;

  final TimelineController timelineController;

  void reset();

  @visibleForTesting
  TimelineEventType inferEventType(TraceEvent event) {
    if (event.phase == TraceEvent.asyncBeginPhase ||
        event.phase == TraceEvent.asyncInstantPhase ||
        event.phase == TraceEvent.asyncEndPhase) {
      return TimelineEventType.async;
    } else if (event.threadId == uiThreadId) {
      return TimelineEventType.ui;
    } else if (event.threadId == gpuThreadId) {
      return TimelineEventType.gpu;
    } else {
      return TimelineEventType.unknown;
    }
  }
}
