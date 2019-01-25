// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

// For documentation, see the Chrome "Trace Event Format" document:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview

class TimelineData {
  TimelineData();

  final List<TimelineThread> threads = <TimelineThread>[];
  final Map<int, TimelineThread> threadMap = <int, TimelineThread>{};

  final StreamController<TimelineThreadEvent> _timelineEventsController =
      StreamController<TimelineThreadEvent>.broadcast();

  void addThread(TimelineThread thread) {
    threads.add(thread);
    threadMap[thread.threadId] = thread;
    threads.sort();
  }

  Stream<TimelineThreadEvent> get onTimelineThreadEvent =>
      _timelineEventsController.stream;

  void processTimelineEvent(TimelineEvent event) {
    final TimelineThread thread = threadMap[event.threadId];
    if (thread == null) {
      return;
    }

    switch (event.phase) {
      case 'B':
        thread._handleDurationBeginEvent(event);
        break;
      case 'E':
        thread._handleDurationEndEvent(event);
        break;
      case 'X':
        thread._handleDurationCompleteEvent(event);
        break;

      case 'b':
        thread._handleAsyncBeginEvent(event);
        break;
      case 'n':
        thread._handleAsyncInstantEvent(event);
        break;
      case 'e':
        thread._handleAsyncEndEvent(event);
        break;

      default:
        // TODO(devoncarew): Support additional phases (s, t, f).
        //print(jsonEncode(event.json));
        break;
    }
  }

  TimelineThread getThread(int threadId) => threadMap[threadId];

  TimelineFrameData getFrameData(TimelineFrame frame) {
    if (frame == null) {
      return null;
    }

    final List<TimelineThreadEvent> events = <TimelineThreadEvent>[];

    for (TimelineThread thread in threads) {
      for (TimelineThreadEvent event in thread.events) {
        if (!event.wellFormed) {
          continue;
        }

        if (event.endMicros >= frame.startMicros &&
            event.startMicros < frame.endMicros) {
          events.add(event);
        }
      }
    }

    return TimelineFrameData(frame, threads, events);
  }

  void printData() {
    for (TimelineThread thread in threads) {
      print('${thread.name}:');
      final StringBuffer buf = StringBuffer();

      for (TimelineThreadEvent event in thread.events) {
        event.format(buf, '  ');
        print(buf.toString().trimRight());
        buf.clear();
      }

      print('');
    }
  }
}

class TimelineThread implements Comparable<TimelineThread> {
  TimelineThread(this.parent, String name, this.threadId) {
    _name = name;

    // "name":"io.flutter.1.ui (42499)",
    if (name.contains(' (') && name.endsWith(')')) {
      _name = name.substring(0, _name.lastIndexOf(' ('));
    }
  }

  final TimelineData parent;
  final int threadId;

  final List<TimelineThreadEvent> events = <TimelineThreadEvent>[];

  TimelineThreadEvent durationStack;

  final Map<String, TimelineThreadEvent> _asyncEvents =
      <String, TimelineThreadEvent>{};

  String _name;

  int get sortPriority {
    if (name.endsWith('.ui')) {
      return 1;
    }
    if (name.endsWith('.gpu')) {
      return 2;
    }
    if (name.startsWith('io.flutter.')) {
      return 3;
    }
    return 4;
  }

  String get name => _name;

  @override
  String toString() => name;

  @override
  int compareTo(TimelineThread other) {
    final int sortPriority1 = sortPriority;
    final int sortPriority2 = other.sortPriority;
    if (sortPriority1 != sortPriority2) {
      return sortPriority1 - sortPriority2;
    }
    return name.compareTo(other.name);
  }

  void _handleDurationBeginEvent(TimelineEvent event) {
    final TimelineThreadEvent e =
        TimelineThreadEvent(event.threadId, event.name);
    e.setStart(event.timestampMicros);

    if (durationStack == null) {
      events.add(e);
      durationStack = e;
    } else {
      durationStack.children.add(e);
      e.parent = durationStack;
      durationStack = e;
    }
  }

  void _handleDurationEndEvent(TimelineEvent event) {
    if (durationStack != null) {
      final TimelineThreadEvent current = durationStack;

      durationStack.setEnd(event.timestampMicros);
      durationStack = durationStack.parent;

      // Fire an event for a completed timeline event.
      if (durationStack == null) {
        parent._timelineEventsController.add(current);
      }
    }
  }

  void _handleDurationCompleteEvent(TimelineEvent event) {
    final TimelineThreadEvent e =
        TimelineThreadEvent(event.threadId, event.name);
    e.setStart(event.timestampMicros);
    e.durationMicros = event.duration;

    if (durationStack == null) {
      events.add(e);
    } else {
      durationStack.children.add(e);
    }
  }

  void _handleAsyncBeginEvent(TimelineEvent event) {
    final String asyncUID = event.asyncUID;

    final TimelineThreadEvent parentEvent = _asyncEvents[asyncUID];
    if (parentEvent == null) {
      final TimelineThreadEvent e =
          TimelineThreadEvent(event.threadId, event.name);
      e.setStart(event.timestampMicros);
      _asyncEvents[asyncUID] = e;
      events.add(e);
    } else {
      final TimelineThreadEvent e =
          TimelineThreadEvent(event.threadId, event.name);
      e.setStart(event.timestampMicros);
      e.parent = parentEvent;
      _asyncEvents[asyncUID] = e;
    }
  }

  void _handleAsyncInstantEvent(TimelineEvent event) {
    final String asyncUID = event.asyncUID;

    final TimelineThreadEvent e =
        TimelineThreadEvent(event.threadId, event.name);
    e.setStart(event.timestampMicros);
    e.durationMicros = event.duration;

    final TimelineThreadEvent parent = _asyncEvents[asyncUID];
    if (parent != null) {
      e.parent = parent;
    } else {
      events.add(e);
    }
  }

  void _handleAsyncEndEvent(TimelineEvent event) {
    final String asyncUID = event.asyncUID;

    final TimelineThreadEvent current = _asyncEvents[asyncUID];
    if (current != null) {
      current.setEnd(event.timestampMicros);
      _asyncEvents[asyncUID] = current.parent;

      // Fire an event for a completed timeline event.
      if (_asyncEvents[asyncUID] == null) {
        parent._timelineEventsController.add(current);
      }
    }
  }
}

class TimelineThreadEvent {
  TimelineThreadEvent(this.threadId, this.name);

  final int threadId;
  final String name;

  TimelineThreadEvent parent;
  List<TimelineThreadEvent> children = <TimelineThreadEvent>[];

  int startMicros;
  int durationMicros;

  void setStart(int micros) {
    startMicros = micros;
  }

  void setEnd(int micros) {
    durationMicros = micros - startMicros;
  }

  int get endMicros => startMicros + (durationMicros ?? 0);

  bool get wellFormed => startMicros != null && durationMicros != null;

  void format(StringBuffer buf, String indent) {
    buf.writeln('$indent$name [${startMicros}u]');
    for (TimelineThreadEvent child in children) {
      child.format(buf, '  $indent');
    }
  }

  @override
  String toString() => '$name, start=$startMicros duration=$durationMicros';
}

class TimelineFrame {
  TimelineFrame({this.renderStart, this.rasterizeStart});

  int renderStart;
  int renderDuration;

  int rasterizeStart;
  int rasterizeDuration;

  int get startMicros => renderStart ?? rasterizeStart;

  int get endMicros {
    if (rasterizeStart != null) {
      return rasterizeStart + rasterizeDuration;
    } else {
      return renderStart + renderDuration;
    }
  }

  void setRenderStart(int micros) {
    renderStart = micros;
  }

  void setRenderEnd(int micros) {
    renderDuration = micros - renderStart;
  }

  void setRasterizeStart(int micros) {
    rasterizeStart = micros;
  }

  void setRasterizeEnd(int micros) {
    if (rasterizeStart != null) {
      rasterizeDuration = micros - rasterizeStart;
    }
  }

  bool get isComplete => renderDuration != null && rasterizeDuration != null;

  String get renderAsMs {
    return '${(renderDuration / 1000.0).toStringAsFixed(1)}ms';
  }

  String get gpuAsMs {
    return '${(rasterizeDuration / 1000.0).toStringAsFixed(1)}ms';
  }

  @override
  String toString() {
    return 'frame render: $renderDuration rasterize: $rasterizeDuration';
  }
}

class TimelineFrameData {
  TimelineFrameData(this.frame, this.threads, this.events);

  final TimelineFrame frame;
  final List<TimelineThread> threads;
  final List<TimelineThreadEvent> events;

  void printData() {
    print(frame.startMicros);
    print('${frame.renderDuration}u');
    print('${frame.rasterizeDuration}u');

    for (TimelineThread thread in threads) {
      print('${thread.name}');
      final StringBuffer buf = StringBuffer();

      for (TimelineThreadEvent event in events) {
        if (event.threadId == thread.threadId) {
          event.format(buf, '  ');
          print('  [${event.name}]');
        }
      }
    }
  }

  Iterable<TimelineThreadEvent> eventsForThread(TimelineThread thread) {
    return events.where(
        (TimelineThreadEvent event) => event.threadId == thread.threadId);
  }
}

// TODO(devoncarew): Upstream this class to the service protocol library.

/// A single timeline event.
class TimelineEvent {
  /// Creates a timeline event given JSON-encoded event data.
  factory TimelineEvent(Map<String, dynamic> json) {
    return TimelineEvent._(json, json['name'], json['cat'], json['ph'],
        json['pid'], json['tid'], json['dur'], json['ts'], json['args']);
  }

  TimelineEvent._(
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

  @override
  String toString() => '[$category] [$phase] $name';
}
