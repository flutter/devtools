// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../utils.dart';
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

/// Protocol for processing trace events and composing them into
/// [TimelineEvents] and [TimelineFrames].
class TimelineProtocol {
  TimelineProtocol({
    @required this.uiThreadId,
    @required this.gpuThreadId,
    @required this.timelineController,
  });

  static const durationBeginPhase = 'B';
  static const durationEndPhase = 'E';
  static const durationCompletePhase = 'X';
  static const flowStartPhase = 's';
  static const flowEndPhase = 'f';

  // TODO(kenzie): Remove the following members once ui/gpu distinction changes
  //  and frame ids are available in the engine.
  final int uiThreadId;
  final int gpuThreadId;
  final TimelineController timelineController;

  /// Frames we are in the process of assembling.
  ///
  /// Once frames are ready, we will remove them from this Map and add them to
  /// the timeline.
  final Map<String, TimelineFrame> pendingFrames = <String, TimelineFrame>{};

  /// Events we have collected and are waiting to add to their respective
  /// frames.
  final List<TimelineEvent> pendingEvents = [];

  /// The current nodes in the tree structures of UI and GPU duration events.
  final List<TimelineEvent> currentEventNodes = [null, null];

  /// The previously handled DurationEnd events for both UI and GPU.
  ///
  /// We need this information to balance the tree structures of our event nodes
  /// if they fall out of balance due to duplicate trace events.
  List<TraceEvent> previousDurationEndEvents = [null, null];

  /// Heaps that order and store trace events as we receive them.
  final List<HeapPriorityQueue<TraceEventWrapper>> heaps = List.generate(
    2,
    (_) => HeapPriorityQueue(),
  );

  void processTraceEvent(TraceEvent event, {bool immediate = false}) {
    // TODO(kenzie): stop manually setting the type once we have that data from
    // the engine.
    event.type = _inferEventType(event);

    if (!_shouldProcessTraceEvent(event)) return;

    // Process flow events now. Process Duration events after a delay. Only
    // process flow events whose name is PipelineItem, as these events mark the
    // start and end for a frame. Processing other types of flow events would
    // lead to us creating Timeline frames where we shouldn't and therefore
    // showing bad data to the user.
    switch (event.phase) {
      case flowStartPhase:
        if (event.name.contains('PipelineItem')) {
          _handleFrameStartEvent(event);
        }
        break;
      case flowEndPhase:
        if (event.name.contains('PipelineItem')) {
          _handleFrameEndEvent(event);
        }
        break;
      default:
        if (immediate) {
          _processDurationEvent(TraceEventWrapper(
            event,
            DateTime.now().millisecondsSinceEpoch,
          ));
        } else {
          // Add trace event to respective heap.
          final heap = heaps[event.type.index];
          heap.add(TraceEventWrapper(
            event,
            DateTime.now().millisecondsSinceEpoch,
          ));
          // Process duration events with a delay.
          executeWithDelay(
            Duration(milliseconds: traceEventDelay.inMilliseconds),
            () => _processDurationEvents(heap),
            executeNow: shouldProcessTopEvent(heap),
          );
        }
    }
  }

  bool shouldProcessTopEvent(HeapPriorityQueue<TraceEventWrapper> heap) {
    return heap.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch - heap.first.timeReceived >=
            traceEventDelay.inMilliseconds;
  }

  void _processDurationEvents(HeapPriorityQueue<TraceEventWrapper> heap) {
    while (heap.isNotEmpty && shouldProcessTopEvent(heap)) {
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
      case durationBeginPhase:
        _handleDurationBeginEvent(eventWrapper);
        break;
      case durationEndPhase:
        _handleDurationEndEvent(eventWrapper);
        break;
      case durationCompletePhase:
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
        !(event.name.contains('VSYNC') ||
            event.name.contains('GPURasterizer::Draw'))) {
      return;
    }

    final timelineEvent = TimelineEvent(eventWrapper);

    if (current != null) {
      current.addChild(timelineEvent);
    }
    currentEventNodes[event.type.index] = timelineEvent;
  }

  void _handleDurationEndEvent(TraceEventWrapper eventWrapper) {
    final TraceEvent event = eventWrapper.event;
    TimelineEvent current = currentEventNodes[event.type.index];

    if (current == null) return;

    // If the names of [event] and [current] do not match, our event nesting is
    // off balance due to duplicate events from the engine. Balance the tree so
    // we can continue processing trace events for [current].
    if (event.name != current.name) {
      if (collectionEquals(
        event.json,
        previousDurationEndEvents[event.type.index]?.json,
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
              previousDurationEndEvents[event.type.index]?.name &&
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

    previousDurationEndEvents[event.type.index] = event;

    current.time.end = Duration(microseconds: event.timestampMicros);
    current.traceEvents.add(eventWrapper);

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
    final TimelineEvent timelineEvent = TimelineEvent(eventWrapper);

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
    pendingEvents.sort((TimelineEvent a, TimelineEvent b) {
      return a.time.start.inMicroseconds.compareTo(b.time.start.inMicroseconds);
    });

    final List<TimelineFrame> frames = _getAndSortWellFormedFrames();
    for (TimelineFrame frame in frames) {
      final List<TimelineEvent> eventsToRemove = [];

      for (TimelineEvent event in pendingEvents) {
        final bool eventAdded = _maybeAddEventToFrame(event, frame);
        if (eventAdded) {
          eventsToRemove.add(event);
          break;
        }
      }

      if (eventsToRemove.isNotEmpty) {
        // ignore: prefer_foreach
        for (TimelineEvent event in eventsToRemove) {
          pendingEvents.remove(event);
        }
      }
    }
  }

  /// Add event to an available frame in [pendingFrames] if we can, or
  /// otherwise add it to [pendingEvents].
  void _maybeAddEvent(TimelineEvent event) {
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
  bool _maybeAddEventToFrame(TimelineEvent event, TimelineFrame frame) {
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

  void _maybeAddCompletedFrame(TimelineFrame frame) async {
    if (frame.isReadyForTimeline && frame.addedToTimeline == null) {
      if (debugTimeline) {
        debugFrameTracking.writeln('Completing ${frame.id}');
      }

      // Record the trace events for this timeline frame.
      timelineController.recordTrace(frame.pipelineItemStartTrace.json);
      timelineController.recordTraceForTimelineEvent(frame.uiEventFlow);
      timelineController.recordTraceForTimelineEvent(frame.gpuEventFlow);
      timelineController.recordTrace(frame.pipelineItemEndTrace.json);

      timelineController.addFrame(frame);
      pendingFrames.remove(frame.id);
      frame.addedToTimeline = true;

      // Pre-fetch the cpu profile for this frame.
      frame.cpuProfileData =
          await timelineController.timelineService.getCpuProfile(
        startMicros: frame.uiEventFlow.time.start.inMicroseconds,
        extentMicros: frame.uiEventFlow.time.duration.inMicroseconds,
      );
      frame.cpuProfileReady.complete();
    }
  }

  bool eventOccursWithinFrameBounds(TimelineEvent e, TimelineFrame f) {
    // TODO(kenzie): talk to the engine team about why we need the epsilon. Why
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

  TimelineEventType _inferEventType(TraceEvent event) {
    if (event.threadId == uiThreadId) {
      return TimelineEventType.ui;
    } else if (event.threadId == gpuThreadId) {
      return TimelineEventType.gpu;
    } else {
      return TimelineEventType.unknown;
    }
  }

  bool _shouldProcessTraceEvent(TraceEvent event) {
    // ignore: prefer_collection_literals
    final Set<String> phaseWhitelist = Set.of([
      flowStartPhase,
      flowEndPhase,
      durationBeginPhase,
      durationEndPhase,
      durationCompletePhase,
    ]);
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
}
