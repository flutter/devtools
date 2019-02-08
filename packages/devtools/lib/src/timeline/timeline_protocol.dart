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

  final StreamController<TimelineFrame> _frameCompleteController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameCompleted => _frameCompleteController.stream;

  /// Frames we are in the process of assembling.
  ///
  /// Once frames are ready, we will remove them from this Map and add them to
  /// [_frameCompleteController].
  final Map<String, TimelineFrame> _pendingFrames = <String, TimelineFrame>{};

  /// Events we have collected and are waiting to add to their respective
  /// frames.
  final List<TimelineEvent> _pendingEvents = [];

  /// The current node in the tree structure of CPU duration events.
  TimelineEvent _cpuEventNode;

  /// The current node in the tree structure of GPU duration events.
  TimelineEvent _gpuEventNode;

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
      // We do not need to handle async events (phases 'b', 'n', 'e') because
      // CPU/GPU work will take place in DurationEvents.
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
      if (_pendingFrames[event.id] == null) {
        // Create a new TimelineFrame if we do not already have one for this id.
        _pendingFrames[event.id] = TimelineFrame(event.id);
      }
      if (_pendingFrames[event.id].startTime == null) {
        _pendingFrames[event.id].startTime = event.timestampMicros;
        _maybeAddPendingEvents();
      } else {
        // TODO(kenzie): investigate and prevent this case.
        print('Error - already set startTime '
            '${_pendingFrames[event.id].startTime} for frame ${event.id}.\n'
            'TraceEvent - ${event.json.toString()}');
      }
    }
  }

  void _handleFrameEndEvent(TraceEvent event) async {
    if (event.id != null) {
      if (_pendingFrames[event.id] == null) {
        // Sometimes frame end events can come in before frame start events, so
        // create a new TimelineFrame if we do not already have one for this id.
        _pendingFrames[event.id] = TimelineFrame(event.id);
      }
      if (_pendingFrames[event.id].endTime == null) {
        _pendingFrames[event.id].endTime = event.timestampMicros;
        _maybeAddPendingEvents();
      } else {
        // TODO(kenzie): investigate and prevent this case.
        print('Error - already set endTime ${_pendingFrames[event.id].endTime}'
            ' for frame ${event.id}.\nTraceEvent - ${event.json.toString()}');
      }
    }
  }

  void _handleDurationBeginEvent(TraceEvent event) {
    final e = TimelineEvent(
      event.name,
      event.timestampMicros,
      event.type,
    );

    if (event.isCpuEvent) {
      if (_cpuEventNode != null) {
        _cpuEventNode.addChild(e);
        _cpuEventNode = e;
      }
      // Do not add MessageLoop::RunExpiredTasks events to a null stack. These
      // events will either a) start outside of our frame start time, or b)
      // parent irrelevant events - neither of which we want.
      else if (!event.name.contains('MessageLoop::RunExpiredTasks')) {
        _cpuEventNode = e;
      }
    } else if (event.isGpuEvent) {
      if (_gpuEventNode != null) {
        _gpuEventNode.addChild(e);
        _gpuEventNode = e;
      }
      // Do not add MessageLoop::RunExpiredTasks events to a null stack. A
      // single MessageLoop::RunExpiredTasks event can parent multiple
      // PipelineConsume event flows, and we want to consider each
      // PipelineConsume flow to be its own event. This event can also parent
      // irrelevant events that we do not want to track.
      else if (!event.name.contains('MessageLoop::RunExpiredTasks')) {
        _gpuEventNode = e;
      }
    }
  }

  void _handleDurationEndEvent(TraceEvent event) {
    TimelineEvent current;
    if (event.isCpuEvent && _cpuEventNode != null) {
      _cpuEventNode.endTime = event.timestampMicros;
      current = _cpuEventNode;

      // Since this event is complete, move back up the stack.
      _cpuEventNode = _cpuEventNode.parent;
      if (_cpuEventNode == null) {
        _maybeAddEvent(current);
      }
    }
    if (event.isGpuEvent && _gpuEventNode != null) {
      _gpuEventNode.endTime = event.timestampMicros;
      current = _gpuEventNode;

      // Since this event is complete, move back up the stack.
      _gpuEventNode = _gpuEventNode.parent;
      if (_gpuEventNode == null) {
        _maybeAddEvent(current);
      }
    }
  }

  void _handleDurationCompleteEvent(TraceEvent event) {
    final e = TimelineEvent(
      event.name,
      event.timestampMicros,
      event.type,
    );
    e.endTime = event.timestampMicros + event.duration;

    if (event.isCpuEvent) {
      if (_cpuEventNode != null) {
        _cpuEventNode.addChild(e, knownChildLocation: false);
      } else {
        _maybeAddEvent(e);
      }
    }
    if (event.isGpuEvent) {
      if (_gpuEventNode != null) {
        _gpuEventNode.addChild(e, knownChildLocation: false);
      } else {
        _maybeAddEvent(e);
      }
    }
  }

  /// Looks through [_pendingEvents] and attempts to add events to frames in
  /// [_pendingFrames].
  void _maybeAddPendingEvents() {
    final frames = _getAndSortWellFormedFrames();
    for (TimelineFrame frame in frames) {
      // Sort _pendingEvents by their startTime. This ensures we will add the
      // first matching event within the time boundary to the frame.
      _pendingEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Make a copy of [_pendingEvents] to iterate through.
      final events = _pendingEvents.toList();

      for (TimelineEvent event in events) {
        final bool eventAdded = _maybeAddEventToFrame(event, frame);
        if (eventAdded) {
          _pendingEvents.remove(event);
        }
      }
    }
  }

  /// Add event to an available frame in [_pendingFrames] if we can, or otherwise add it
  /// to [_pendingEvents].
  void _maybeAddEvent(TimelineEvent event) {
    if (!event.isCpuEventFlow && !event.isGpuEventFlow) {
      // We do not care about events that are neither the main flow of CPU
      // events nor the main flow of GPU events.
      return;
    }

    bool eventAdded = false;

    final frames = _getAndSortWellFormedFrames();
    for (TimelineFrame frame in frames) {
      eventAdded = _maybeAddEventToFrame(event, frame);
    }

    if (!eventAdded) {
      _pendingEvents.add(event);
    }
  }

  /// Add event [e] to frame [f] if it meets the necessary criteria.
  ///
  /// Returns a bool indicating whether the event was added to the frame.
  bool _maybeAddEventToFrame(TimelineEvent e, TimelineFrame f) {
    assert(f.isWellFormed);

    // TODO(kenzie): consider trimming VSYNC layer from pipelineProduceFlow. It
    // can start outside of the frame's time boundaries and could pose a risk
    // for us missing a frame.

    // Ensure the event fits within the frame's time boundaries.
    if (!_eventOccursWithinFrameBoundaries(e, f)) {
      return false;
    }

    bool eventAdded = false;

    if (e.isCpuEventFlow && f.cpuEventFlow == null) {
      f.cpuEventFlow = e;
      eventAdded = true;
    } else if (e.isGpuEventFlow && f.gpuEventFlow == null) {
      f.gpuEventFlow = e;
      eventAdded = true;
    }

    // Adding event [e] could mean we have completed the frame. Check if we
    // should add the completed frame to [_frameCompleteController].
    _maybeAddCompletedFrame(f);

    return eventAdded;
  }

  bool _eventOccursWithinFrameBoundaries(TimelineEvent e, TimelineFrame f) {
    // TODO(kenzie): talk to the engine team about why we need the epsilon. Why
    // do event times extend slightly beyond the times we get from frame start
    // and end flow events.

    // Epsilon in microseconds.
    const int epsilon = 50;

    // Allow the event to extend the frame boundaries by [epsilon] microseconds.
    final bool fitsStartBoundary = f.startTime - e.startTime - epsilon < 0;
    final bool fitsEndBoundary = f.endTime - e.endTime + epsilon > 0;

    // The [gpuEventFlow] should always start after the [cpuEventFlow].
    bool satisfiesCpuGpuOrder() {
      if (e.isCpuEventFlow && f.gpuEventFlow != null) {
        return e.startTime < f.gpuEventFlow.startTime;
      } else if (e.isGpuEventFlow && f.cpuEventFlow != null) {
        return e.startTime > f.cpuEventFlow.startTime;
      }
      // We do not have enough information about the frame to compare CPU and
      // GPU start times, so return true.
      return true;
    }

    return fitsStartBoundary && fitsEndBoundary && satisfiesCpuGpuOrder();
  }

  List<TimelineFrame> _getAndSortWellFormedFrames() {
    final frames = _pendingFrames.values
        .toList()
        .where((frame) => frame.isWellFormed)
        .toList();

    // Sort frames by their startTime. Sorting these frames ensures we will
    // handle the oldest frame first when iterating through the list.
    frames.sort((a, b) => a.startTime.compareTo(b.startTime));
    return frames;
  }

  void _maybeAddCompletedFrame(TimelineFrame frame) {
    if (frame.isReadyForTimeline && frame.addedToTimeline == null) {
      _frameCompleteController.add(frame);
      _pendingFrames.remove(frame);
      frame.addedToTimeline = true;
    }
  }
}

/// Data describing a single frame.
///
/// Each TimelineFrame should have 2 distinct pieces of data:
/// * [cpuEventFlow] : flow of events showing the CPU work for the frame.
/// * [gpuEventFlow] : flow of events showing the GPU work for the frame.
class TimelineFrame {
  TimelineFrame(this.id);

  final String id;

  // TODO(kenzie): we should query the device for targetFps at some point.
  static const targetFps = 60;
  static const targetMaxDuration = 1000 / targetFps;

  /// Marks whether this frame has been added to the timeline.
  ///
  /// This should only be set once.
  bool get addedToTimeline => _addedToTimeline;
  bool _addedToTimeline;
  set addedToTimeline(v) {
    assert(_addedToTimeline == null);
    _addedToTimeline = v;
  }

  /// Flow of events showing the CPU work for the frame.
  TimelineEvent get cpuEventFlow => _cpuEventFlow;
  TimelineEvent _cpuEventFlow;
  set cpuEventFlow(TimelineEvent e) {
    assert(_cpuEventFlow == null, 'cpuEventFlow already set');
    _cpuEventFlow = e;
  }

  /// Flow of events showing the GPU work for the frame.
  TimelineEvent get gpuEventFlow => _gpuEventFlow;
  TimelineEvent _gpuEventFlow;
  set gpuEventFlow(TimelineEvent e) {
    assert(_gpuEventFlow == null, 'gpuEventFlow already set');
    _gpuEventFlow = e;
  }

  /// Whether the frame is ready for the timeline.
  ///
  /// A frame is ready once it has both required event flows as well as
  /// [startTime] and [endTime].
  bool get isReadyForTimeline {
    return _cpuEventFlow != null &&
        _gpuEventFlow != null &&
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

  bool get isWellFormed => _startTime != null && _endTime != null;

  /// Duration the frame took to render in micros.
  int get duration =>
      endTime != null && startTime != null ? endTime - startTime : null;

  // Timing info for CPU portion of the frame.
  int get cpuStartTime => _cpuEventFlow.startTime;
  int get cpuEndTime => cpuStartTime + cpuDuration;
  int get cpuDuration => _cpuEventFlow.duration;
  double get cpuDurationMs => cpuDuration / 1000;

  // Timing info for GPU portion of the frame.
  int get gpuStartTime => _gpuEventFlow.startTime;
  int get gpuEndTime => gpuStartTime + gpuDuration;
  int get gpuDuration => _gpuEventFlow.duration;
  double get gpuDurationMs => gpuDuration / 1000;

  bool get isCpuSlow => cpuDurationMs > targetMaxDuration / 2;
  bool get isGpuSlow => gpuDurationMs > targetMaxDuration / 2;

  String get cpuAsMs {
    return _durationAsMsText(cpuDurationMs);
  }

  String get gpuAsMs {
    return _durationAsMsText(gpuDurationMs);
  }

  String _durationAsMsText(double durationMs) {
    return '${durationMs.toStringAsFixed(1)}ms';
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

  bool get isCpuEventFlow => _hasChild('Engine::BeginFrame');
  bool get isGpuEventFlow => _hasChild('PipelineConsume');

  /// Whether there is a child with the given name [childName] is contained
  /// somewhere in the subtree [children].
  bool _hasChild(String childName) {
    bool findChild(TimelineEvent event, String childName) {
      if (event.name.contains(childName)) {
        return true;
      }
      for (TimelineEvent e in event.children) {
        return findChild(e, childName);
      }
      return false;
    }

    return findChild(this, childName);
  }

  void addChild(TimelineEvent child, {bool knownChildLocation = true}) {
    // Places the child in it's correct position amongst the other children.
    void _putChildInSubtree(TimelineEvent root) {
      // [root] is a leaf. Add child here.
      if (root.children.isEmpty) {
        root._addChild(child);
        return;
      }

      final _children = root.children.toList();
      for (TimelineEvent otherChild in _children) {
        // [child] is the parent of [otherChild].
        if (child._isParentOf(otherChild)) {
          // Link [otherChild] with its correct parent [child].
          child._addChild(otherChild);

          // Unlink [otherChild] from its incorrect parent [root].
          root.children.remove(otherChild);
        }

        // [otherChild] is the parent of [child].
        if (otherChild._isParentOf(child)) {
          // Recurse on [otherChild]'s subtree.
          _putChildInSubtree(otherChild);
        }
      }

      // If we have not returned at this point, [child] belongs in
      // [root.children].
      root._addChild(child);
    }

    if (knownChildLocation) {
      // For DurationBegin events, we can guarantee they will be received in
      // increasing timestamp order and we can guarantee the nesting order. This
      // means we know the child's location in the tree and we can add it
      // directly.
      _addChild(child);
    } else {
      // For DurationComplete events, we cannot guarantee they will be received
      // in increasing timestamp order. Because a DurationComplete event tells
      // us both the startTime and endTime, we also can't guarantee the nesting
      // order of these events. Therefore, we must properly order and nest the
      // events as we add them.
      _putChildInSubtree(this);
    }
  }

  void _addChild(TimelineEvent child) {
    if (!children.contains(child)) {
      children.add(child);
      child.parent = this;
    }
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

  // TODO(kenzie): use DiagnosticableTreeMixin instead.
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
