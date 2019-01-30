// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

// For documentation, see the Chrome "Trace Event Format" document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview

enum TimelineEventType {
  cpu,
  gpu,
}

// TODO(kenzie): re-assess all event handling logic. Ensure the parent/children
// relationships are accurate.
class TimelineData {
  TimelineData({this.cpuThreadId, this.gpuThreadId});

  // TODO(kenzie): Remove these members once cpu/gpu distinction changes are
  // available in the engine.
  final int cpuThreadId;
  final int gpuThreadId;
  int frameId = 0;

  final Map<int, TimelineFrame> frames = <int, TimelineFrame>{};
  final StreamController<TimelineFrame> _frameCompleteController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameCompleted => _frameCompleteController.stream;

  final Map<String, TimelineEvent> _asyncEvents = <String, TimelineEvent>{};
  TimelineEvent durationStack;

  void processTimelineEvent(TraceEvent event) {
    // TODO(kenzie): Remove this logic once cpu/gpu distinction changes are
    // available in the engine.
    event.frameId ??= frameId;
    event.type ??= event.threadId == cpuThreadId
        ? TimelineEventType.cpu
        : TimelineEventType.gpu;

    // We only care about CPU and GPU events.
    if (event.type != TimelineEventType.cpu &&
        event.type != TimelineEventType.gpu &&
        event.phase != 's') {
      return;
    }

    // Always handle frame start events. This is where we add the first
    // [TimelineFrame] to [frames].
    if (event.phase == 's') {
      _handleFrameStartEvent(event);
    }

    // Only handle events for frames that we are aware of (i.e. we have handled
    // the start frame event and added a [TimelineFrame] to [frames] with the
    // given id).
    if (frames.containsKey(event.frameId)) {
      switch (event.phase) {
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
  }

  void _handleFrameStartEvent(TraceEvent event) {
    // TODO(kenzie): this should be an assert once we have the actual frameId
    // from the event. Since we are manually creating frame ids for now, we will
    // only handle a start frame event once the previous frame has finished.
    // This means, for now, we will skip a frame when its start event overlaps
    // with an incomplete frame.
    if (!frames.containsKey(event.frameId)) {
      frames[event.frameId] =
          TimelineFrame(event.frameId, event.timestampMicros);
    }
  }

  void _handleFrameEndEvent(TraceEvent event) {
    final frame = frames[event.frameId];
    frame.endTime = event.timestampMicros;
    _frameCompleteController.add(frame);
    frameId++;
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

  final int id;

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

  // TODO(kenzie): remove getters and setters for the following properties once
  //  CPU/GPU distinction data is available in the engine.
  int _frameId;
  int get frameId => _frameId ?? args['frameId'];
  set frameId(int id) => _frameId = id;

  TimelineEventType _type;
  TimelineEventType get type {
    if (_type == null) {
      if (args['type'] == 'cpu') _type = TimelineEventType.cpu;
      if (args['type'] == 'gpu') _type = TimelineEventType.gpu;
    }
    return _type;
  }

  set type(TimelineEventType t) => _type = t;

  bool get isCpuEvent => type == TimelineEventType.cpu;
  bool get isGpuEvent => type == TimelineEventType.gpu;

  @override
  String toString() => '$type event for frame $frameId - [$category] [$phase] '
      '$name - [timestamp: $timestampMicros] [duration: $duration]';
}
