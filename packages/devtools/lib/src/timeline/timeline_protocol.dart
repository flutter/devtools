// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

// For documentation, see the Chrome "Trace Event Format" document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview

// Switch this flag to true to dump timeline events to console.
bool _debugEventTrace = false;

enum TimelineEventType {
  cpu,
  gpu,
  unknown,
}

class TimelineData {
  TimelineData({this.cpuThreadId, this.gpuThreadId});

  // TODO(kenzie): Remove the following members once cpu/gpu distinction changes
  //  and frame ids are available in the engine.
  final int cpuThreadId;
  final int gpuThreadId;
  String frameId;

  // Maps frame ids to their respective frames.
  final Map<String, TimelineFrame> _frames = <String, TimelineFrame>{};

  final List<TimelineEvent> _pendingEvents = [];

  final StreamController<TimelineFrame> _frameCompleteController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameCompleted => _frameCompleteController.stream;

  final Map<String, TimelineEvent> _asyncEvents = <String, TimelineEvent>{};
  TimelineEvent _cpuDurationStack;
  TimelineEvent _gpuDurationStack;

  void processTimelineEvent(TraceEvent event) {
    // TODO(kenzie): stop manually setting the type once we have that data from
    // the engine.
    event.type = _inferEventType(event);

    if (!event.isGpuEvent && !event.isCpuEvent) return;

    if (_debugEventTrace) print(event.toString());

    switch (event.phase) {
      case 's':
        _handleFrameStartEvent(event);
        break;
      case 'f':
        _handleFrameEndEvent(event);
        break;
      case 'B':
        _handleDurationBeginEvent(event);
        break;
      case 'E':
        _handleDurationEndEvent(event);
        break;
      case 'X':
        _handleDurationCompleteEvent(event);
        break;
      case 'b':
        _handleAsyncBeginEvent(event);
        break;
      case 'n':
        _handleAsyncInstantEvent(event);
        break;
      case 'e':
        _handleAsyncEndEvent(event);
        break;
    }
  }

  TimelineEventType _inferEventType(TraceEvent event) {
    if (event.threadId == cpuThreadId) {
      return TimelineEventType.cpu;
    } else if (event.threadId == gpuThreadId) {
      return TimelineEventType.gpu;
    } else {
      return TimelineEventType.unknown;
    }
  }

  void _handleFrameStartEvent(TraceEvent event) {
    if (event.id != null) {
      if (_frames[event.id] == null) {
        // Create a new TimelineFrame if we do not already have one for this id.
        _frames[event.id] = TimelineFrame(event.id);
      }
      _frames[event.id].startTime = event.timestampMicros;
      _maybeAddPendingEvents();
    }
  }

  void _handleFrameEndEvent(TraceEvent event) async {
    if (event.id != null) {
      if (_frames[event.id] == null) {
        // Sometimes frame end events can come in before frame start events, so
        // create a new TimelineFrame if we do not already have one for this id.
        _frames[event.id] = TimelineFrame(event.id);
      }
      _frames[event.id].endTime = event.timestampMicros;
      _maybeAddPendingEvents();
    }
  }

  void _handleDurationBeginEvent(TraceEvent event) {
    final TimelineEvent e = TimelineEvent(
      event.name,
      event.timestampMicros,
      event.type,
    );

    if (event.isCpuEvent) {
      if (_cpuDurationStack != null) {
        _cpuDurationStack.addChild(e);
        _cpuDurationStack = e;
      }
      // Do not add these events to a null stack. MessageLoop::RunExpiredTasks
      // will either a) start outside of our frame start time, or b) parent
      // irrelevant events - neither of which do we want.
      else if (!event.name.contains('MessageLoop::RunExpiredTasks')) {
        _cpuDurationStack = e;
      }
    } else if (event.isGpuEvent) {
      if (_gpuDurationStack != null) {
        _gpuDurationStack.addChild(e);
        _gpuDurationStack = e;
      }
      // Do not add these events to a null stack. A single
      // MessageLoop::RunExpiredTasks event can parent multiple PipelineConsume
      // event flows, and we want to consider each PipelineConsume flow to be
      // its own event. MessageLoop::RunExpiredTasks can also parent irrelevant
      // events that we do not want to track.
      else if (!event.name.contains('MessageLoop::RunExpiredTasks')) {
        _gpuDurationStack = e;
      }
    }
  }

  void _handleDurationEndEvent(TraceEvent event) {
    TimelineEvent current;
    if (event.isCpuEvent && _cpuDurationStack != null) {
      _cpuDurationStack.endTime = event.timestampMicros;
      current = _cpuDurationStack;

      // Since this event is complete, move back up the stack.
      _cpuDurationStack = _cpuDurationStack.parent;
      if (_cpuDurationStack == null) {
        _maybeAddEvent(current);
      }
    } else if (event.isGpuEvent && _gpuDurationStack != null) {
      _gpuDurationStack.endTime = event.timestampMicros;
      current = _gpuDurationStack;

      // Since this event is complete, move back up the stack.
      _gpuDurationStack = _gpuDurationStack.parent;
      if (_gpuDurationStack == null) {
        _maybeAddEvent(current);
      }
    }
  }

  void _handleDurationCompleteEvent(TraceEvent event) {
    final TimelineEvent e = TimelineEvent(
      event.name,
      event.timestampMicros,
      event.type,
    );
    e.endTime = event.timestampMicros + event.duration;

    if (event.isCpuEvent) {
      if (_cpuDurationStack != null) {
        _cpuDurationStack.addChild(e, findChildLocation: true);
      } else {
        _maybeAddEvent(e);
      }
    }

    if (event.isGpuEvent) {
      if (_gpuDurationStack != null) {
        _gpuDurationStack.addChild(e, findChildLocation: true);
      } else {
        _maybeAddEvent(e);
      }
    }
  }

  // TODO(kenzie): consider removing async event handling if the events we are
  // interested in are guaranteed not to be async. Check with Chinmay.
  void _handleAsyncBeginEvent(TraceEvent event) {
    final TimelineEvent e = TimelineEvent(
      event.name,
      event.timestampMicros,
      event.type,
    );

    final String asyncUID = event.asyncUID;
    if (_asyncEvents[asyncUID] != null) {
      e.parent = _asyncEvents[asyncUID];
    }
    _asyncEvents[asyncUID] = e;
  }

  void _handleAsyncEndEvent(TraceEvent event) {
    final String asyncUID = event.asyncUID;

    if (_asyncEvents[asyncUID] != null) {
      _asyncEvents[asyncUID].endTime = event.timestampMicros;

      final TimelineEvent current = _asyncEvents[asyncUID];

      // Since this event is complete, move back up the stack.
      _asyncEvents[asyncUID] = current.parent;

      if (_asyncEvents[asyncUID] == null) {
        _asyncEvents.remove(asyncUID);
        _maybeAddEvent(current);
      }
    }
  }

  void _handleAsyncInstantEvent(TraceEvent event) {
    final TimelineEvent e = TimelineEvent(
      event.name,
      event.timestampMicros,
      event.type,
    );
    e.endTime = event.timestampMicros + event.duration;

    final String asyncUID = event.asyncUID;
    if (_asyncEvents[asyncUID] != null) {
      _asyncEvents[asyncUID].addChild(e, findChildLocation: true);
    } else {
      _maybeAddEvent(e);
    }
  }

  /// Looks through [_pendingEvents] and attempts to add events to frames in
  /// [_frames].
  void _maybeAddPendingEvents() {
    final List<TimelineFrame> frames = _getAndSortWellFormedFrames();
    for (TimelineFrame frame in frames) {
      // Sort _pendingEvents by their startTime. This ensures we will add the
      // first matching event within the time boundary to the frame.
      _pendingEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Make a copy of `_pendingEvents` to iterate through.
      final List<TimelineEvent> events =
          List<TimelineEvent>.from(_pendingEvents);

      for (TimelineEvent event in events) {
        final bool eventAdded = _maybeAddEventToFrame(event, frame);
        if (eventAdded) _pendingEvents.remove(event);
      }
    }
  }

  /// Add event to an available frame in [_frames] if we can, or otherwise add it
  /// to [_pendingEvents].
  void _maybeAddEvent(TimelineEvent event) {
    if (!event.isPipelineProduceFlow && !event.isPipelineConsumeFlow) {
      // We do not care about other events.
      return;
    }

    bool eventAdded = false;

    final List<TimelineFrame> frames = _getAndSortWellFormedFrames();
    for (TimelineFrame frame in frames) {
      eventAdded = _maybeAddEventToFrame(event, frame);
    }

    if (!eventAdded) _pendingEvents.add(event);
  }

  /// Add event `e` to frame `f` if it meets the necessary criteria.
  ///
  /// Returns a bool indicating whether the event was added to the frame.
  bool _maybeAddEventToFrame(TimelineEvent e, TimelineFrame f) {
    assert(f.wellFormed);

    // TODO(kenzie): consider trimming VSYNC layer from pipelineProduceFlow. It
    // can start outside of the frame's time boundaries and could pose a risk
    // for us missing a frame.

    // Ensure the event fits within the frame's time boundaries.
    if (!_eventOccursWithinFrameBoundaries(e, f)) return false;

    bool eventAdded = false;

    if (e.isPipelineProduceFlow && f.pipelineProduceFlow == null) {
      f.pipelineProduceFlow = e;
      eventAdded = true;
    } else if (e.isPipelineConsumeFlow && f.pipelineConsumeFlow == null) {
      f.pipelineConsumeFlow = e;
      eventAdded = true;
    }

    // Adding event 'e' could mean we have completed the frame. Check if we
    // should add the completed frame to [_frameCompleteController].
    _maybeAddCompletedFrame(f);

    return eventAdded;
  }

  bool _eventOccursWithinFrameBoundaries(TimelineEvent e, TimelineFrame f) {
    // Epsilon in microseconds.
    const int epsilon = 50;

    // Allow the event to extend the frame boundaries by `epsilon` microseconds.
    final bool fitsStartBoundary = f.startTime - e.startTime - epsilon < 0;
    final bool fitsEndBoundary = f.endTime - e.endTime + epsilon > 0;
    return fitsStartBoundary && fitsEndBoundary;
  }

  List<TimelineFrame> _getAndSortWellFormedFrames() {
    final List<TimelineFrame> frames = List<TimelineFrame>.from(_frames.values)
        .where((TimelineFrame f) => f.wellFormed)
        .toList();

    // Sort frames by their startTime. Sorting these frames ensures we will
    // handle the oldest frame first when iterating through the list.
    frames.sort((a, b) => a.startTime.compareTo(b.startTime));
    return frames;
  }

  void _maybeAddCompletedFrame(TimelineFrame frame) {
    if (frame.readyForTimeline && !frame.addedToTimeline.isCompleted) {
      _frameCompleteController.add(frame);
      _frames.remove(frame);
      frame.addedToTimeline.complete();
    }
  }
}

/// Data describing a single frame.
///
/// Each TimelineFrame should have 4 distinct pieces of data:
///   - [_pipelineProduceFlow] : flow of events showing the CPU work for the
///     frame.
///   - [_pipelineConsumeFlow] : flow of events showing the GPU work for the
///     frame.
class TimelineFrame {
  TimelineFrame(this.id);

  final String id;

  /// Marks whether this frame has been added to the timeline.
  Completer<Null> addedToTimeline = Completer();

  /// Flow of events showing the CPU work for the frame.
  TimelineEvent get pipelineProduceFlow => _pipelineProduceFlow;

  /// Flow of events showing the GPU work for the frame.
  TimelineEvent get pipelineConsumeFlow => _pipelineConsumeFlow;

  TimelineEvent _pipelineProduceFlow;
  TimelineEvent _pipelineConsumeFlow;

  set pipelineProduceFlow(TimelineEvent e) {
    assert(_pipelineProduceFlow == null, 'pipelineProduceFlow already set');
    _pipelineProduceFlow = e;
  }

  set pipelineConsumeFlow(TimelineEvent e) {
    assert(_pipelineConsumeFlow == null, 'pipelineConsumeFlow already set');
    _pipelineConsumeFlow = e;
  }

  /// Whether the frame is ready for the timeline.
  ///
  /// A frame is ready once it has both required event flows as well as
  /// [startTime] and [endTime].
  bool get readyForTimeline {
    return _pipelineProduceFlow != null &&
        _pipelineConsumeFlow != null &&
        _startTime != null &&
        _endTime != null;
  }

  /// Frame start time in micros.
  int get startTime => _startTime;
  int _startTime;
  set startTime(int t) {
    assert(_startTime == null);
    _startTime = t;
  }

  /// Frame end time in micros.
  int get endTime => _endTime;
  int _endTime;
  set endTime(int t) {
    assert(_endTime == null);
    _endTime = t;
  }

  bool get wellFormed => _startTime != null && _endTime != null;

  /// Duration the frame took to render in micros.
  int get duration =>
      endTime != null && startTime != null ? endTime - startTime : null;

  // Timing info for CPU portion of the frame.
  int get cpuStartTime => _pipelineProduceFlow.startTime;
  int get cpuEndTime => cpuStartTime + cpuDuration;
  int get cpuDuration => _pipelineProduceFlow.duration;

  // Timing info for GPU portion of the frame.
  int get gpuStartTime => _pipelineConsumeFlow.startTime;
  int get gpuEndTime => gpuStartTime + gpuDuration;
  int get gpuDuration => _pipelineConsumeFlow.duration;

  String get cpuAsMs {
    return _durationAsMsText(cpuDuration);
  }

  String get gpuAsMs {
    return _durationAsMsText(gpuDuration);
  }

  String _durationAsMsText(int durationMicros) {
    return '${(durationMicros / 1000.0).toStringAsFixed(1)}ms';
  }

  @override
  String toString() {
    return 'Frame $id - start: $startTime end: $endTime total dur: $duration '
        'cpu: [start $cpuStartTime dur $cpuDuration] gpu: [start: $gpuStartTime'
        ' dur $gpuDuration]';
  }
}

class TimelineEvent {
  TimelineEvent(this.name, this.startTime, this.type);

  final String name;
  final int startTime;
  final TimelineEventType type;

  int endTime;

  TimelineEvent parent;
  List<TimelineEvent> children = <TimelineEvent>[];

  int get duration => (endTime != null) ? endTime - startTime : null;

  bool get isCpuEvent => type == TimelineEventType.cpu;
  bool get isGpuEvent => type == TimelineEventType.gpu;

  bool get isPipelineProduceFlow => _hasChild('Engine::BeginFrame');
  bool get isPipelineConsumeFlow => _hasChild('PipelineConsume');

  /// Whether there is a child with the given name [childName] is contained
  /// somewhere in the subtree [children].
  bool _hasChild(String childName) {
    bool childFound = false;

    void findChild(TimelineEvent event, String childName) {
      if (event.name.contains(childName)) {
        childFound = true;
      }
      if (childFound) return;
      for (TimelineEvent e in event.children) {
        findChild(e, childName);
      }
    }

    findChild(this, childName);
    return childFound;
  }

  /// Adds a child event.
  ///
  /// If we know the child's location (knownLocation == true)
  /// add the child directly via [_addChild]. If we do not know the child's
  /// location, find it's proper place in the subtree and add the child there.
  void addChild(TimelineEvent child, {bool findChildLocation = false}) {
    bool newChildAdded = false;

    // Places the child in it's correct position amongst the other children.
    void _putChildInSubtree(TimelineEvent root, TimelineEvent newChild) {
      // [root] is a leaf. Add child here.
      if (root.children.isEmpty) {
        root._addChild(child);
        newChildAdded = true;
      }

      if (newChildAdded) return;

      final List<TimelineEvent> _children =
          List<TimelineEvent>.from(root.children);
      for (int i = 0; i < _children.length; i++) {
        final TimelineEvent currentChild = _children[i];

        // [newChild] is the parent of [currentChild].
        if (newChild._isParentOf(currentChild)) {
          // Link [currentChild] with its correct parent [newChild].
          newChild._addChild(currentChild);

          // Unlink [child] from its incorrect parent [this].
          root.children.remove(currentChild);

          // Link [newChild] with its correct parent [this].
          if (!newChildAdded) _addChild(newChild);

          newChildAdded = true;
        }

        // [child] is the parent of [newChild].
        if (currentChild._isParentOf(newChild)) {
          // Recurse on [currentChild]'s subtree.
          _putChildInSubtree(currentChild, newChild);
        }
      }

      // If we have not added the child at this point, [currentChild] and
      // [newChild] are siblings.
      if (!newChildAdded) {
        root._addChild(newChild);
        newChildAdded = true;
        return;
      }
    }

    if (findChildLocation) {
      _putChildInSubtree(this, child);
    } else {
      _addChild(child);
    }
  }

  void _addChild(TimelineEvent child) {
    children.add(child);
    child.parent = this;
  }

  // TODO(kenzie): consider comparing with an epsilon for endTime.
  bool _isParentOf(TimelineEvent e) {
    if (endTime != null && e.endTime != null) {
      return startTime < e.startTime && endTime > e.endTime;
    } else {
      return startTime < e.startTime;
    }
  }

  void format(StringBuffer buf, String indent) {
    buf.writeln(
        '$indent$name [start: $startTime] [end: $endTime] [dur: $duration]');
    for (TimelineEvent child in children) {
      child.format(buf, '  $indent');
    }
  }

  @override
  String toString() => '[$type] $name [start $startTime] [end $endTime] [dur '
      '$duration] \n'
      '  - parent: ${parent != null ? parent.name : 'null'} \n'
      '  - children.length: ${children.length}';
}

// TODO(devoncarew): Upstream this class to the service protocol library.

/// A single timeline event.
class TraceEvent {
  /// Creates a timeline event given JSON-encoded event data.
  factory TraceEvent(Map<String, dynamic> json) {
    return TraceEvent._(json, json['name'], json['cat'], json['ph'],
        json['pid'], json['tid'], json['dur'], json['ts'], json['args']);
  }

  TraceEvent._(
    this.json,
    this.name,
    this.category,
    this.phase,
    this.processId,
    this.threadId,
    this.duration,
    this.timestampMicros,
    this.args,
  );

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
        _type = TimelineEventType.cpu;
      } else if (args['type'] == 'gpu') {
        _type = TimelineEventType.gpu;
      } else {
        _type = TimelineEventType.unknown;
      }
    }
    return _type;
  }

  set type(TimelineEventType t) => _type = t;

  bool get isCpuEvent => type == TimelineEventType.cpu;
  bool get isGpuEvent => type == TimelineEventType.gpu;

  @override
  String toString() => '$type event [id: $id] [cat: $category] [ph: $phase] '
      '$name - [timestamp: $timestampMicros] [duration: $duration]';
}
