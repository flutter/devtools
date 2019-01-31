// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

// For documentation, see the Chrome "Trace Event Format" document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview

enum TimelineEventType {
  cpu,
  gpu,
  unknown,
}

// TODO(kenzie): re-assess all event handling logic. Ensure the parent/children
// relationships are accurate.
class TimelineData {
  TimelineData({this.cpuThreadId, this.gpuThreadId});

  // TODO(kenzie): Remove the following members once cpu/gpu distinction changes
  //  and frame ids are available in the engine.
  final int cpuThreadId;
  final int gpuThreadId;
  String frameId;

  // TODO(kenzie): stop depending on this once we have frame ids.
  // Marks whether we have received a frame start event. Since we aren't certain
  // of event frame ids right now, we should only listen for events after the
  // start frame event and before the end frame event.
  bool _listeningForFrameEvents = false;

  // Maps frame ids to their respective frames.
  final Map<String, TimelineFrame> frames = <String, TimelineFrame>{};
  final StreamController<TimelineFrame> _frameCompleteController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameCompleted => _frameCompleteController.stream;

  final Map<String, TimelineEvent> _asyncEvents = <String, TimelineEvent>{};
  TimelineEvent durationStack;

  void processTimelineEvent(TraceEvent event) {
    // TODO(kenzie): stop manually setting the type once we have that data from
    // the engine.
    event.type = _inferEventType(event);

    // Always handle frame start and end events.
    if (event.phase == 's') {
      _handleFrameStartEvent(event);
      return;
    } else if (event.phase == 'f') {
      _handleFrameEndEvent(event);
      return;
    }

    // Only handle events that take place between frame start and frame end.
    if (_listeningForFrameEvents) {
      // TODO(kenzie): stop manually setting the frame id once we have ids from
      // the engine.
      event.frameId ??= frameId;

      // We only care about CPU and GPU events.
      if (event.type != TimelineEventType.cpu &&
          event.type != TimelineEventType.gpu) {
        return;
      }

      // Only handle events for frames that we are aware of (i.e. we have handled
      // the start frame event and added a [TimelineFrame] to [frames] with the
      // given id).
      if (frames.containsKey(event.frameId)) {
        switch (event.phase) {
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
    // We should not be receiving multiple frame start events with the same id.
    assert(!frames.containsKey(event.frameId));

    // Only handle one frame at a time. If we are currently listening for frame
    // events, then the frame has already started.
    if (!_listeningForFrameEvents) {
      // TODO(kenzie): stop manually setting the frame id once we have ids from
      // the engine.
      frameId = event.id;
      event.frameId = event.id;

      frames[event.frameId] =
          TimelineFrame(event.frameId, event.timestampMicros);
      _listeningForFrameEvents = true;
    }
  }

  void _handleFrameEndEvent(TraceEvent event) {
    // Only handle frame end events for frames we know about (i.e. we have
    // received the frame start event for this frame and have been listening for
    // its events).
    if (frames.containsKey(event.id)) {
      final frame = frames[event.id];
      frame.endTime = event.timestampMicros;
      _frameCompleteController.add(frame);
      _listeningForFrameEvents = false;
    }
  }

  void _handleDurationBeginEvent(TraceEvent event) {
    final TimelineEvent e = TimelineEvent(
      event.name,
      event.timestampMicros,
      _getTimelineEventType(event),
    );
    if (durationStack == null) {
      durationStack = e;
    } else {
      durationStack.children.add(e);
      e.parent = durationStack;
      durationStack = e;
    }
  }

  void _handleDurationEndEvent(TraceEvent event) {
    if (durationStack != null) {
      final TimelineEvent current = durationStack;
      durationStack.endTime = event.timestampMicros;

      // Since this event is complete, move back up the stack.
      durationStack = durationStack.parent;

      if (durationStack == null) {
        frames[event.frameId].addEvent(current);
      }
    }
  }

  void _handleDurationCompleteEvent(TraceEvent event) {
    final TimelineEvent e = TimelineEvent(
      event.name,
      event.timestampMicros,
      _getTimelineEventType(event),
    );
    e.endTime = event.timestampMicros + event.duration;

    if (durationStack != null) {
      durationStack.children.add(e);
    }
  }

  void _handleAsyncBeginEvent(TraceEvent event) {
    final String asyncUID = event.asyncUID;

    final TimelineEvent parentEvent = _asyncEvents[asyncUID];
    if (parentEvent == null) {
      final TimelineEvent e = TimelineEvent(
        event.name,
        event.timestampMicros,
        _getTimelineEventType(event),
      );
      _asyncEvents[asyncUID] = e;
    } else {
      final TimelineEvent e = TimelineEvent(
        event.name,
        event.timestampMicros,
        _getTimelineEventType(event),
      );
      e.parent = parentEvent;
      _asyncEvents[asyncUID] = e;
    }
  }

  void _handleAsyncInstantEvent(TraceEvent event) {
    final String asyncUID = event.asyncUID;

    final TimelineEvent e = TimelineEvent(
      event.name,
      event.timestampMicros,
      _getTimelineEventType(event),
    );
    e.endTime = event.timestampMicros + event.duration;

    final TimelineEvent parent = _asyncEvents[asyncUID];
    if (parent != null) {
      e.parent = parent;
    }
  }

  void _handleAsyncEndEvent(TraceEvent event) {
    final String asyncUID = event.asyncUID;

    final TimelineEvent current = _asyncEvents[asyncUID];
    if (current != null) {
      current.endTime = event.timestampMicros;
      _asyncEvents[asyncUID] = current.parent;

      if (_asyncEvents[asyncUID] == null) {
        frames[event.frameId].addEvent(current);
      }
    }
  }

  TimelineEventType _getTimelineEventType(TraceEvent event) {
    // The event will only be of type 'cpu' or 'gpu' because we do not process
    // events of any other type.
    if (event.isCpuEvent) {
      return TimelineEventType.cpu;
    } else {
      return TimelineEventType.gpu;
    }
  }
}

class TimelineFrame {
  TimelineFrame(this.id, this.startTime);

  final String id;

  final List<TimelineEvent> cpuEvents = [];
  final List<TimelineEvent> gpuEvents = [];

  /// Frame start time in micros.
  final int startTime;

  /// Frame end time in micros.
  int endTime;

  // TODO(kenzie): investigate why we are getting negative duration values
  // TODO(kenzie): once correct frame data is available from the engine, verify
  //  we have non-zero values for cpu/gpu durations when expected.

  /// Duration the frame took to render in micros.
  int get duration => endTime - startTime;

  // Timing info for CPU portion of the frame.
  int get cpuStartTime => cpuEvents.isNotEmpty ? cpuEvents.first.startTime : 0;
  int get cpuDuration {
    return cpuEvents.isNotEmpty
        ? cpuEvents.last.startTime + cpuEvents.last.duration - cpuStartTime
        : 0;
  }

  int get cpuEndTime => cpuStartTime + cpuDuration;

  // Timing info for GPU portion of the frame.
  int get gpuStartTime => gpuEvents.isNotEmpty ? gpuEvents.first.startTime : 0;
  int get gpuDuration {
    return gpuEvents.isNotEmpty
        ? gpuEvents.last.startTime + gpuEvents.last.duration - gpuStartTime
        : 0;
  }

  int get gpuEndTime => gpuStartTime + gpuDuration;

  bool get isComplete => cpuDuration != null && gpuDuration != null;

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
    return 'Frame $id - total duration: $duration cpu: $cpuDuration gpu: '
        '$gpuDuration';
  }

  void addEvent(TimelineEvent event) {
    if (!event.wellFormed) return;

    if (event.isCpuEvent) {
      cpuEvents.add(event);
    } else if (event.isGpuEvent) {
      gpuEvents.add(event);
    }
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

  int get duration => endTime - startTime;

  bool get wellFormed => startTime != null && duration != null;

  bool get isCpuEvent => type == TimelineEventType.cpu;
  bool get isGpuEvent => type == TimelineEventType.gpu;

  void format(StringBuffer buf, String indent) {
    buf.writeln('$indent$name [${startTime}u]');
    for (TimelineEvent child in children) {
      child.format(buf, '  $indent');
    }
  }

  @override
  String toString() => '$name, start=$startTime duration=$duration';
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

  // TODO(kenzie): remove setters for these members once we get the data from
  //  the engine.
  String _frameId;
  String get frameId => _frameId ?? args['frameId'];
  set frameId(String id) => _frameId = id;

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
  String toString() =>
      '$type event [frameId: $frameId] [id: $id] [cat: $category] [ph: $phase] '
      '$name - [timestamp: $timestampMicros] [duration: $duration]';
}
