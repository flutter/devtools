// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import '../config_specific/logger/logger.dart';
import '../trace_event.dart';
import '../utils.dart';
//import '../simple_trace_example.dart';
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

const String rasterEventName = 'GPURasterizer::Draw';

const String uiEventName = 'Engine::BeginFrame';

const String messageLoopFlushTasks = 'MessageLoop::FlushTasks';

// For Flutter apps, PipelineItem flow events signal frame start and end events.
const String pipelineItem = 'PipelineItem';

/// Processor for composing a recorded list of trace events into a timeline of
/// [AsyncTimelineEvent]s, [SyncTimelineEvent]s, and [TimelineFrame]s.
class TimelineProcessor {
  TimelineProcessor(this.timelineController);

  /// Number of traceEvents we will process in each batch.
  static const _defaultBatchSize = 2000;

  final TimelineController timelineController;

  /// Notifies with the current progress value of processing Timeline data.
  ///
  /// This value should sit between 0.0 and 1.0.
  ValueListenable get progressNotifier => _progressNotifier;
  final _progressNotifier = ValueNotifier<double>(0.0);

  int _traceEventsProcessed = 0;

  /// Async timeline events we have processed, mapped to their respective async
  /// ids.
  final _asyncEventsById = <String, AsyncTimelineEvent>{};

  /// The current timeline event nodes for duration events.
  ///
  /// The events are mapped to their thread id. As we process duration events,
  /// a timeline event on a single thread will be formed and completed before
  /// another timeline event on the same thread begins.
  @visibleForTesting
  final currentDurationEventNodes = <int, SyncTimelineEvent>{};

  /// The previously handled DurationEnd events for each thread.
  ///
  /// We need this information to balance the tree structures of our event nodes
  /// if they fall out of balance due to duplicate trace events.
  ///
  /// Bug tracking dupes: https://github.com/flutter/flutter/issues/47020.
  final _previousDurationEndEvents = <int, TraceEvent>{};

  /// Frames we are in the process of assembling.
  ///
  /// Once frames have a start and end time, we will remove them from this Map
  /// and add them to the timeline.
  @visibleForTesting
  final pendingFrames = <String, TimelineFrame>{};

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
  SyncTimelineEvent _pendingRootCompleteEvent;

  // TODO(kenz): Remove the [uiThreadId] and [rasterThreadId] once ui/raster
  //  distinction changes and frame ids are available in the engine.
  int uiThreadId;

  int rasterThreadId;

  Future<void> processTimeline(
    List<TraceEventWrapper> traceEvents, {
    bool resetAfterProcessing = true,
  }) async {
    // Reset the processor before processing.
    reset();

// Uncomment this code for testing the timeline.
//    traceEvents = simpleTraceEvents['traceEvents']
//        .where((json) =>
//            json.containsKey(TraceEvent.timestampKey)) // thread_name events
//        .map((e) => TraceEventWrapper(
//            TraceEvent(e), DateTime.now().microsecondsSinceEpoch))
//        .toList();
    final _traceEvents = (traceEvents.where((event) {
      // Throw out 'MessageLoop::FlushTasks' events. A single
      // 'MessageLoop::FlushTasks' event can parent multiple Flutter frame event
      // sequences and complicates the frame detection logic.
      final isMessageLoopFlushTasks =
          event.event.name.contains(messageLoopFlushTasks);
      // Throw out timeline events that do not have a timestamp
      // (e.g. thread_name events) as well as events from before we started
      // recording.
      final ts = event.event.timestampMicros;
      return ts != null && !isMessageLoopFlushTasks;
    }).toList())
      // Events need to be in increasing timestamp order.
      ..sort()
      ..map((event) => event.event.json)
          .toList()
          .forEach(timelineController.recordTrace);

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

    for (var rootEvent in _asyncEventsById.values.where((e) => e.isRoot)) {
      // Do not add incomplete async trees to the timeline.
      // TODO(kenz): infer missing end times based on other end times in the
      // async event tree. Add these "repaired" events to the timeline.
      if (!rootEvent.isWellFormedDeep) continue;

      timelineController.addTimelineEvent(rootEvent);
    }

    _addPendingCompleteRootToTimeline(force: true);

    pendingFrames.values.forEach(_maybeAddCompletedFrame);

    timelineController.data.timelineEvents.sort((a, b) =>
        a.time.start.inMicroseconds.compareTo(b.time.start.inMicroseconds));
    if (timelineController.data.timelineEvents.isNotEmpty) {
      timelineController.data.time
        // We process trace events in timestamp order, so we can ensure the first
        // trace event has the earliest starting timestamp.
        ..start = Duration(
            microseconds: timelineController
                .data.timelineEvents.first.time.start.inMicroseconds)
        // We cannot guarantee that the last trace event is the latest timestamp
        // in the timeline. DurationComplete events' timestamps refer to their
        // starting timestamp, but their end time is derived from the same trace
        // via the "dur" field. For this reason, we use the cached value stored in
        // [timelineController.fullTimeline].
        ..end =
            Duration(microseconds: timelineController.data.endTimestampMicros);
    } else {
      timelineController.data.time
        ..start = Duration.zero
        ..end = Duration.zero;
    }

    if (resetAfterProcessing) {
      reset();
    }
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
        // TODO(kenz): add additional support for flows.
        case TraceEvent.flowStartPhase:
          if (eventWrapper.event.name.contains(pipelineItem)) {
            _handleFrameStartEvent(eventWrapper.event);
          }
          break;
        case TraceEvent.flowEndPhase:
          if (eventWrapper.event.name.contains(pipelineItem)) {
            _handleFrameEndEvent(eventWrapper.event);
          }
          break;
        default:
          break;
      }
    }
  }

  void _addPendingCompleteRootToTimeline({
    int currentProcessingTime,
    bool force = false,
  }) {
    assert(currentProcessingTime != null || force);
    if (_pendingRootCompleteEvent != null &&
        (force ||
            currentProcessingTime >
                _pendingRootCompleteEvent.time.end.inMicroseconds)) {
      timelineController.addTimelineEvent(_pendingRootCompleteEvent);
      _pendingRootCompleteEvent = null;
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
      final parent = _asyncEventsById[parentId];
      if (parent != null) {
        parent.addChild(timelineEvent);
      }
      _asyncEventsById[eventWrapper.event.id] = timelineEvent;
      return;
    }

    final currentEventWithId = _asyncEventsById[eventWrapper.event.id];

    // If we already have a timeline event with the same async id as
    // [timelineEvent] (e.g. [currentEventWithId]), then [timelineEvent] is
    // either a child of [currentEventWithId] or a new root event with this id.
    if (currentEventWithId != null) {
      if (currentEventWithId.isWellFormedDeep) {
        // [timelineEvent] is a new root with the same id as
        // [currentEventWithId]. Since [currentEventWithId] is well formed, add
        // it to the timeline.
        timelineController.addTimelineEvent(currentEventWithId);
        _asyncEventsById[eventWrapper.event.id] = timelineEvent;
      } else {
        if (currentEventWithId.isWellFormed) {
          // Since parent id was not explicitly passed in the event args and
          // since we process events in timestamp order, if [currentEventWithId]
          // is well formed, [timelineEvent] cannot be a child of
          // [currentEventWithId]. This is an illegal id collision that we need
          // to handle gracefully, so throw this event away.
          // Bug tracking collisions:
          // https://github.com/flutter/flutter/issues/47019.
          log('Id collision on id ${eventWrapper.event.id}', LogLevel.warning);
        } else {
          // We know it must be a child because we process events in timestamp
          // order.
          currentEventWithId.addChild(timelineEvent);
        }
      }
    } else {
      _asyncEventsById[eventWrapper.event.id] = timelineEvent;
    }
  }

  void _endAsyncEvent(TraceEventWrapper eventWrapper) {
    final AsyncTimelineEvent root = _asyncEventsById[eventWrapper.event.id];
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
        _previousDurationEndEvents[event.threadId]?.json,
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
              _previousDurationEndEvents[event.threadId]?.name &&
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

    _previousDurationEndEvents[event.threadId] = event;

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

    // If we have reached a null parent, this event is fully formed - add it to
    // the timeline and try to assign it to a Flutter frame.
    if (current.parent == null) {
      if (debugTimeline) {
        debugFrameTracking.writeln('Trying to add event after DurationEnd:');
        current.format(debugFrameTracking, '   ');
      }
      timelineController.addTimelineEvent(current);
      // TODO(kenz): only make this call if we are connected to a Flutter app.
      _maybeAddFlutterFrameEvent(current);
    }
  }

  void _handleDurationCompleteEvent(TraceEventWrapper eventWrapper) {
    final event = eventWrapper.event;
    final timelineEvent = SyncTimelineEvent(eventWrapper)
      ..time.end =
          Duration(microseconds: event.timestampMicros + event.duration);

    final current = currentDurationEventNodes[event.threadId];
    if (current != null) {
      if (current.subtreeHasNodeWithCondition(
          (TimelineEvent event) => collectionEquals(
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
      if (_pendingRootCompleteEvent == null) {
        _pendingRootCompleteEvent = timelineEvent;
      } else {
        _pendingRootCompleteEvent.addChild(timelineEvent);
      }
    }
  }

  void _handleFrameStartEvent(TraceEvent event) {
    if (event.id == null) return;
    final pendingFrame = _frameFromEvent(event);
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
    _maybeAddCompletedFrame(pendingFrame);
  }

  void _handleFrameEndEvent(TraceEvent event) async {
    if (event.id == null) return;
    // Since we handle events in ascending timestamp order, we should ignore
    // frame end events that we receive before the corresponding frame start
    // event.
    if (!pendingFrames.containsKey(_frameId(event))) return;
    final pendingFrame = _frameFromEvent(event);
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
    _maybeAddCompletedFrame(pendingFrame);
  }

  /// Add event to an available frame in [pendingFrames] if we can.
  void _maybeAddFlutterFrameEvent(SyncTimelineEvent event) {
    if (!(event.isUiEventFlow &&
            event.traceEvents.first.event.threadId == uiThreadId) &&
        !(event.isRasterEventFlow &&
            event.traceEvents.first.event.threadId == rasterThreadId)) {
      // We do not care about events that are neither the main flow of UI
      // events nor the main flow of Raster events.
      return;
    }

    final frames = pendingFrames.values
        .where((frame) => frame.pipelineItemTime.start != null)
        .toList()
          ..sort((TimelineFrame a, TimelineFrame b) {
            return a.pipelineItemTime.start.inMicroseconds
                .compareTo(b.pipelineItemTime.start.inMicroseconds);
          });
    for (TimelineFrame frame in frames) {
      final eventAdded = _maybeAddEventToFrame(event, frame);
      if (eventAdded) {
        break;
      }
    }
  }

  /// Attempts to add [event] to [frame], and returns a bool indicating whether
  /// the attempt was successful.
  bool _maybeAddEventToFrame(SyncTimelineEvent event, TimelineFrame frame) {
    // Ensure the frame does not already have an event of this type and that
    // the event fits within the frame's time boundaries.
    if (frame.eventFlows[event.type.index] != null ||
        !satisfiesUiRasterOrder(event, frame)) return false;

    frame.setEventFlow(event);

    // Adding event [e] could mean we have completed the frame. Check if we
    // should add the completed frame to [_frameCompleteController].
    _maybeAddCompletedFrame(frame);

    return true;
  }

  // The [rasterEventFlow] should always start after the [uiEventFlow].
  @visibleForTesting
  bool satisfiesUiRasterOrder(SyncTimelineEvent e, TimelineFrame f) {
    if (e.isUiEventFlow && f.rasterEventFlow != null) {
      return e.time.start.inMicroseconds <
          f.rasterEventFlow.time.start.inMicroseconds;
    } else if (e.isRasterEventFlow && f.uiEventFlow != null) {
      return e.time.start.inMicroseconds >
          f.uiEventFlow.time.start.inMicroseconds;
    }
    // We do not have enough information about the frame to compare UI and
    // Raster start times, so return true.
    return true;
  }

  void _maybeAddCompletedFrame(TimelineFrame frame) {
    assert(pendingFrames.containsKey(frame.id));
    if (frame.isReadyForTimeline) {
      timelineController.addFrame(frame);
      pendingFrames.remove(frame.id);
    }
  }

  TimelineFrame _frameFromEvent(TraceEvent event) {
    final id = _frameId(event);
    return pendingFrames.putIfAbsent(id, () => TimelineFrame(id));
  }

  String _frameId(TraceEvent event) {
    return '${event.name}-${event.id}';
  }

  void reset() {
    _asyncEventsById.clear();
    currentDurationEventNodes.clear();
    _previousDurationEndEvents.clear();
    pendingFrames.clear();
    _pendingRootCompleteEvent = null;
    _traceEventsProcessed = 0;
    _progressNotifier.value = 0.0;
  }

  void primeThreadIds(
      {@required int uiThreadId, @required int rasterThreadId}) {
    this.uiThreadId = uiThreadId;
    this.rasterThreadId = rasterThreadId;
  }

  @visibleForTesting
  TimelineEventType inferEventType(TraceEvent event) {
    if (event.phase == TraceEvent.asyncBeginPhase ||
        event.phase == TraceEvent.asyncInstantPhase ||
        event.phase == TraceEvent.asyncEndPhase) {
      return TimelineEventType.async;
    } else if (event.threadId == uiThreadId) {
      return TimelineEventType.ui;
    } else if (event.threadId == rasterThreadId) {
      return TimelineEventType.raster;
    } else {
      return TimelineEventType.unknown;
    }
  }
}
