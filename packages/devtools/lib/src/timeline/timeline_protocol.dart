// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../utils.dart';

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

/// List that will store trace events in the order we process them.
///
/// These events are scrubbed so that bad data from the engine does not hinder
/// event processing or trace viewing. When the export timeline button is
/// clicked, this will be part of the output.
List<Map<String, dynamic>> timelineTraceEvents = [];

enum TimelineEventType {
  ui,
  gpu,
  unknown,
}

/// Epsilon in micros used for determining it an event fits within a given frame
/// boundary.
///
/// This epsilon will not be used if the duration of the event is less than 2000
/// micros (2 ms). We do this to hold a requirement that at least half of the
/// event must fit within the frame boundaries.
const Duration traceEventEpsilon = Duration(microseconds: 1000);

/// Delay in ms for processing trace events.
const Duration traceEventDelay = Duration(milliseconds: 1000);

class TimelineData {
  TimelineData({this.uiThreadId, this.gpuThreadId});

  static const durationBeginPhase = 'B';
  static const durationEndPhase = 'E';
  static const durationCompletePhase = 'X';
  static const flowStartPhase = 's';
  static const flowEndPhase = 'f';

  // TODO(kenzie): Remove the following members once ui/gpu distinction changes
  //  and frame ids are available in the engine.
  final int uiThreadId;
  final int gpuThreadId;

  final StreamController<TimelineFrame> _frameCompleteController =
      StreamController<TimelineFrame>.broadcast();

  Stream<TimelineFrame> get onFrameCompleted => _frameCompleteController.stream;

  /// Frames we are in the process of assembling.
  ///
  /// Once frames are ready, we will remove them from this Map and add them to
  /// [_frameCompleteController].
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
                .getRoot()
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
          .containsChildWithCondition((TimelineEvent e) => collectionEquals(
                e.beginTraceEventJson,
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

  void _maybeAddCompletedFrame(TimelineFrame frame) {
    if (frame.isReadyForTimeline && frame.addedToTimeline == null) {
      if (debugTimeline) {
        debugFrameTracking.writeln('Completing ${frame.id}');
      }

      // Record the trace events for this timeline frame.
      timelineTraceEvents.add(frame.pipelineItemStartTrace.json);
      frame.uiEventFlow.recordTrace();
      frame.gpuEventFlow.recordTrace();
      timelineTraceEvents.add(frame.pipelineItemEndTrace.json);

      _frameCompleteController.add(frame);
      pendingFrames.remove(frame.id);
      frame.addedToTimeline = true;
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

/// Data describing a single frame.
///
/// Each TimelineFrame should have 2 distinct pieces of data:
/// * [uiEventFlow] : flow of events showing the UI work for the frame.
/// * [gpuEventFlow] : flow of events showing the GPU work for the frame.
class TimelineFrame {
  TimelineFrame(this.id);

  final String id;

  // TODO(kenzie): we should query the device for targetFps at some point.
  static const targetFps = 60.0;
  static const targetMaxDuration = 1000.0 / targetFps;

  /// Marks whether this frame has been added to the timeline.
  ///
  /// This should only be set once.
  bool get addedToTimeline => _addedToTimeline;
  bool _addedToTimeline;

  set addedToTimeline(v) {
    assert(_addedToTimeline == null);
    _addedToTimeline = v;
  }

  /// Event flows for the UI and GPU work for the frame.
  final List<TimelineEvent> eventFlows = List.generate(2, (_) => null);

  /// Flow of events describing the UI work for the frame.
  TimelineEvent get uiEventFlow => eventFlows[TimelineEventType.ui.index];

  /// Flow of events describing the GPU work for the frame.
  TimelineEvent get gpuEventFlow => eventFlows[TimelineEventType.gpu.index];

  /// Whether the frame is ready for the timeline.
  ///
  /// A frame is ready once it has both required event flows as well as
  /// [_pipelineItemStartTime] and [_pipelineItemEndTime].
  bool get isReadyForTimeline {
    return uiEventFlow != null &&
        gpuEventFlow != null &&
        pipelineItemTime.start?.inMicroseconds != null &&
        pipelineItemTime.end?.inMicroseconds != null;
  }

  // Stores frame start time, end time, and duration.
  final time = TimeRange();

  /// Pipeline item time range in micros.
  ///
  /// This stores the start and end times for the pipeline item event for this
  /// frame. We use this value to determine whether a TimelineEvent fits within
  /// the frame's time boundaries.
  final pipelineItemTime = TimeRange(singleAssignment: false);

  TraceEvent pipelineItemStartTrace;

  TraceEvent pipelineItemEndTrace;

  bool get isWellFormed =>
      pipelineItemTime.start?.inMicroseconds != null &&
      pipelineItemTime.end?.inMicroseconds != null;

  int get uiDuration =>
      uiEventFlow != null ? uiEventFlow.time.duration.inMicroseconds : null;

  double get uiDurationMs => uiDuration != null ? uiDuration / 1000 : null;

  int get gpuDuration =>
      gpuEventFlow != null ? gpuEventFlow.time.duration.inMicroseconds : null;

  double get gpuDurationMs => gpuDuration != null ? gpuDuration / 1000 : null;

  void setEventFlow(TimelineEvent event, {TimelineEventType type}) {
    type ??= event?.type;

    eventFlows[type.index] = event;

    if (type == TimelineEventType.ui) {
      time.start = event?.time?.start;
    }
    if (type == TimelineEventType.gpu) {
      time.end = event?.time?.end;
    }
  }

  @override
  String toString() {
    return 'Frame $id - $time, ui: ${uiEventFlow.time}, '
        'gpu: ${gpuEventFlow.time}';
  }
}

class TimelineEvent {
  TimelineEvent(TraceEventWrapper firstTraceEvent)
      : traceEvents = [firstTraceEvent],
        type = firstTraceEvent.event.type {
    time.start = Duration(microseconds: firstTraceEvent.event.timestampMicros);
  }

  /// Trace events associated with this [TimelineEvent].
  ///
  /// There will either be one entry in the list (for DurationComplete events)
  /// or two (one for the associated DurationBegin event and one for the
  /// associated DurationEnd event).
  final List<TraceEventWrapper> traceEvents;

  @visibleForTesting
  TimelineEventType type;

  TimeRange time = TimeRange();

  TimelineEvent parent;

  List<TimelineEvent> children = [];

  String get name => traceEvents.first.event.name;

  Map<String, dynamic> get beginTraceEventJson => traceEvents.first.json;

  Map<String, dynamic> get endTraceEventJson =>
      traceEvents.length > 1 ? traceEvents.last.json : null;

  bool get isUiEvent => type == TimelineEventType.ui;

  bool get isGpuEvent => type == TimelineEventType.gpu;

  bool get isUiEventFlow => containsChildWithCondition(
      (TimelineEvent event) => event.name.contains('Engine::BeginFrame'));

  bool get isGpuEventFlow => containsChildWithCondition(
      (TimelineEvent event) => event.name.contains('PipelineConsume'));

  /// Depth of this TimelineEvent tree, including [this].
  ///
  /// We assume that TimelineEvent nodes are not modified after the first time
  /// [depth] is accessed. We would need to clear the cache if this was
  /// supported.
  int get depth {
    if (_depth != 0) {
      return _depth;
    }
    for (TimelineEvent child in children) {
      _depth = max(_depth, child.depth);
    }
    return _depth = _depth + 1;
  }

  int _depth = 0;

  TimelineEvent getRoot() {
    TimelineEvent root = this;
    while (root.parent != null) {
      root = root.parent;
    }
    return root;
  }

  bool containsChildWithCondition(bool condition(TimelineEvent _)) {
    bool _containsChildWithCondition(
      TimelineEvent root,
      bool condition(TimelineEvent _),
    ) {
      if (condition(root)) {
        return true;
      }
      for (TimelineEvent newRoot in root.children) {
        if (_containsChildWithCondition(newRoot, condition)) {
          return true;
        }
      }
      return false;
    }

    return _containsChildWithCondition(this, condition);
  }

  void maybeRemoveDuplicate() {
    void _maybeRemoveDuplicate({@required TimelineEvent parent}) {
      if (parent.children.length == 1 &&
          // [parent]'s DurationBegin trace is equal to that of its only child.
          collectionEquals(
            parent.beginTraceEventJson,
            parent.children.first.beginTraceEventJson,
          ) &&
          // [parent]'s DurationEnd trace is equal to that of its only child.
          collectionEquals(
            parent.endTraceEventJson,
            parent.children.first.endTraceEventJson,
          )) {
        parent.removeChild(children.first);
      }
    }

    // Remove [this] event's child if it is a duplicate of [this].
    if (children.isNotEmpty) {
      _maybeRemoveDuplicate(parent: this);
    }
    // Remove [this] event if it is a duplicate of [parent].
    if (parent != null) {
      _maybeRemoveDuplicate(parent: parent);
    }
  }

  void removeChild(TimelineEvent childToRemove) {
    assert(children.contains(childToRemove));
    final List<TimelineEvent> newChildren = List.from(childToRemove.children);
    newChildren.forEach(_addChild);
    children.remove(childToRemove);
  }

  void addChild(TimelineEvent child) {
    // Places the child in it's correct position amongst the other children.
    void _putChildInTree(TimelineEvent root) {
      // [root] is a leaf. Add child here.
      if (root.children.isEmpty) {
        root._addChild(child);
        return;
      }

      final _children = root.children.toList();

      // If [child] is the parent of some or all of the members in [_children],
      // those members will need to be reordered in the tree.
      final childrenToReorder = [];
      for (TimelineEvent otherChild in _children) {
        if (child.couldBeParentOf(otherChild)) {
          childrenToReorder.add(otherChild);
        }
      }

      if (childrenToReorder.isNotEmpty) {
        root._addChild(child);

        for (TimelineEvent otherChild in childrenToReorder) {
          // Link [otherChild] with its correct parent [child].
          child._addChild(otherChild);

          // Unlink [otherChild] from its incorrect parent [root].
          root.children.remove(otherChild);
        }
        return;
      }

      // Check if a member of [_children] is the parent of [child]. If multiple
      // children in [_children] share a timestamp, they both could be the
      // parent of [child]. We reverse [_children] so that we will pick the last
      // received candidate as the new parent of [child].
      for (TimelineEvent otherChild in _children.reversed) {
        if (otherChild.couldBeParentOf(child)) {
          // Recurse on [otherChild]'s subtree.
          _putChildInTree(otherChild);
          return;
        }
      }

      // If we have not returned at this point, [child] belongs in
      // [root.children].
      root._addChild(child);
    }

    _putChildInTree(this);
  }

  void _addChild(TimelineEvent child) {
    assert(!children.contains(child));
    children.add(child);
    child.parent = this;
  }

  bool couldBeParentOf(TimelineEvent e) {
    final startTime = time.start.inMicroseconds;
    final endTime = time.end?.inMicroseconds;
    final eStartTime = e.time.start.inMicroseconds;
    final eEndTime = e.time.end?.inMicroseconds;

    if (endTime != null && eEndTime != null) {
      if (startTime == eStartTime && endTime == eEndTime) {
        return traceEvents.first.id < e.traceEvents.first.id;
      }
      return startTime <= eStartTime && endTime >= eEndTime;
    } else if (endTime != null) {
      // We don't use >= to compare [endTime] and [e.startTime] here because we
      // don't want to falsely make [this] the parent of [e]. We do not know
      // [e.endTime], meaning [e] could start at [endTime] and end later than
      // [endTime] (unless e has a duration of 0). In this case, [this] would
      // not be the parent of [e].
      return startTime <= eStartTime && endTime > eStartTime;
    } else if (startTime == eStartTime) {
      return traceEvents.first.id < e.traceEvents.first.id;
    } else {
      return startTime < eStartTime;
    }
  }

  void format(StringBuffer buf, String indent) {
    buf.writeln('$indent$name $time');
    for (TimelineEvent child in children) {
      child.format(buf, '  $indent');
    }
  }

  void formatFromRoot(StringBuffer buf, String indent) {
    getRoot().format(buf, indent);
  }

  void writeTraceToBuffer(StringBuffer buf) {
    buf.writeln(beginTraceEventJson);
    for (TimelineEvent child in children) {
      child.writeTraceToBuffer(buf);
    }
    if (endTraceEventJson != null) {
      buf.writeln(endTraceEventJson);
    }
  }

  void recordTrace() {
    timelineTraceEvents.add(beginTraceEventJson);
    for (TimelineEvent event in children) {
      event.recordTrace();
    }
    if (endTraceEventJson != null) {
      timelineTraceEvents.add(endTraceEventJson);
    }
  }

  @visibleForTesting
  TimelineEvent deepCopy() {
    final copy = TimelineEvent(traceEvents.first);
    copy.time.end = time.end;
    copy.parent = parent;
    for (TimelineEvent child in children) {
      copy._addChild(child.deepCopy());
    }
    return copy;
  }

  // TODO(kenzie): use DiagnosticableTreeMixin instead.
  @override
  String toString() {
    final buf = StringBuffer();
    format(buf, '  ');
    return buf.toString();
  }
}

// TODO(devoncarew): Upstream this class to the service protocol library.

/// A single timeline event.
class TraceEvent {
  /// Creates a timeline event given JSON-encoded event data.
  TraceEvent(this.json)
      : name = json['name'],
        category = json['cat'],
        phase = json['ph'],
        processId = json['pid'],
        threadId = json['tid'],
        duration = json['dur'],
        timestampMicros = json['ts'],
        args = json['args'];

  /// The original event JSON.
  final Map<String, dynamic> json;

  /// The name of the event.
  ///
  /// Corresponds to the "name" field in the JSON event.
  final String name;

  /// Event category. Events with different names may share the same category.
  ///
  /// Corresponds to the "cat" field in the JSON event.
  final String category;

  /// For a given long lasting event, denotes the phase of the event, such as
  /// "B" for "event began", and "E" for "event ended".
  ///
  /// Corresponds to the "ph" field in the JSON event.
  final String phase;

  /// ID of process that emitted the event.
  ///
  /// Corresponds to the "pid" field in the JSON event.
  final int processId;

  /// ID of thread that issues the event.
  ///
  /// Corresponds to the "tid" field in the JSON event.
  final int threadId;

  /// Each async event has an additional required parameter id. We consider the
  /// events with the same category and id as events from the same event tree.
  dynamic get id => json['id'];

  /// An optional scope string can be specified to avoid id conflicts, in which
  /// case we consider events with the same category, scope, and id as events
  /// from the same event tree.
  String get scope => json['scope'];

  /// The duration of the event, in microseconds.
  ///
  /// Note, some events are reported with duration. Others are reported as a
  /// pair of begin/end events.
  ///
  /// Corresponds to the "dur" field in the JSON event.
  final int duration;

  /// Time passed since tracing was enabled, in microseconds.
  final int timestampMicros;

  /// Arbitrary data attached to the event.
  final Map<String, dynamic> args;

  String get asyncUID {
    if (scope == null) {
      return '$category:$id';
    } else {
      return '$category:$scope:$id';
    }
  }

  TimelineEventType _type;

  TimelineEventType get type {
    if (_type == null) {
      if (args['type'] == 'ui') {
        _type = TimelineEventType.ui;
      } else if (args['type'] == 'gpu') {
        _type = TimelineEventType.gpu;
      } else {
        _type = TimelineEventType.unknown;
      }
    }
    return _type;
  }

  set type(TimelineEventType t) => _type = t;

  bool get isUiEvent => type == TimelineEventType.ui;

  bool get isGpuEvent => type == TimelineEventType.gpu;

  @override
  String toString() => '$type event [id: $id] [cat: $category] [ph: $phase] '
      '$name - [timestamp: $timestampMicros] [duration: $duration]';
}

int _traceEventWrapperId = 0;

class TraceEventWrapper implements Comparable<TraceEventWrapper> {
  TraceEventWrapper(this.event, this.timeReceived)
      : id = _traceEventWrapperId++;
  final TraceEvent event;

  final num timeReceived;

  final int id;

  Map<String, dynamic> get json => event.json;

  bool processed = false;

  @override
  int compareTo(TraceEventWrapper other) {
    // Order events based on their timestamps. If the events share a timestamp,
    // order them in the order we received them.
    final compare =
        event.timestampMicros.compareTo(other.event.timestampMicros);
    return compare != 0 ? compare : id.compareTo(other.id);
  }
}
