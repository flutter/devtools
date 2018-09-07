// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO: tests

class TimelineData {
  final List<TimelineThread> threads;
  final Map<int, TimelineThread> threadMap = <int, TimelineThread>{};

  final Map<int, TimelineThreadData> threadData = <int, TimelineThreadData>{};

  TimelineData(this.threads) {
    for (TimelineThread thread in threads) {
      threadMap[thread.threadId] = thread;
      threadData[thread.threadId] = new TimelineThreadData(this);
    }
  }

  void processTimelineEvent(TimelineEvent event) {
    final TimelineThread thread = threadMap[event.threadId];
    if (thread == null) {
      return;
    }

    final TimelineThreadData data = threadData[event.threadId];

    switch (event.phase) {
      case 'B':
        data.handleDurationBeginEvent(event);
        break;
      case 'E':
        data.handleDurationEndEvent(event);
        break;
      case 'X':
        data.handleCompleteEvent(event);
        break;

      default:
        // TODO(devoncarew): Support additional phases.
        print('unhandled phase: ${event.phase}');
        break;
    }
  }

  TimelineFrameData getFrameData(TimelineFrame frame) {
    if (frame == null) {
      return null;
    }

    final List<TEvent> events = <TEvent>[];

    for (TimelineThreadData data in threadData.values) {
      for (TEvent event in data.events) {
        if (!event.wellFormed) {
          continue;
        }

        if (event.endMicros >= frame.start && event.startMicros < frame.end) {
          events.add(event);
        }
      }
    }

    return TimelineFrameData(frame, threads, events);
  }

  void printData() {
    for (TimelineThread thread in threads) {
      print('${thread.name}:');
      final StringBuffer buf = new StringBuffer();
      final TimelineThreadData data = threadData[thread.threadId];

      for (TEvent event in data.events) {
        event.format(buf, '  ');
        print(buf.toString().trimRight());
        buf.clear();
      }

      print('');
    }
  }
}

class TimelineThread implements Comparable<TimelineThread> {
  final int threadId;

  String _name;

  TimelineThread(String name, this.threadId) {
    _name = name;

    // "name":"io.flutter.1.ui (42499)",
    if (name.contains(' (') && name.endsWith(')')) {
      _name = name.substring(0, _name.lastIndexOf(' ('));
    }
  }

  bool get isVisible => name.startsWith('io.flutter.');

  int get category {
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
    final int c1 = category;
    final int c2 = other.category;
    if (c1 != c2) {
      return c1 - c2;
    }
    return name.compareTo(other.name);
  }
}

class TimelineThreadData {
  final TimelineData parent;
  final List<TEvent> events = <TEvent>[];

  TimelineThreadData(this.parent);

  List<TEvent> durationStack = <TEvent>[];

  void handleDurationBeginEvent(TimelineEvent event) {
    final TEvent e = new TEvent(event.threadId, event.name);
    e.setStart(event.timestampMicros);

    if (durationStack.isEmpty) {
      events.add(e);
    } else {
      durationStack.last.children.add(e);
    }

    durationStack.add(e);
  }

  void handleDurationEndEvent(TimelineEvent event) {
    if (durationStack.isNotEmpty) {
      final TEvent e = durationStack.removeLast();
      e.setEnd(event.timestampMicros);
    }
  }

  void handleCompleteEvent(TimelineEvent event) {
    final TEvent e = new TEvent(event.threadId, event.name);
    e.setStart(event.timestampMicros);
    e.durationMicros = event.duration;

    if (durationStack.isEmpty) {
      events.add(e);
    } else {
      durationStack.last.children.add(e);
    }
  }
}

// TODO: rename to timelinethreadevent
class TEvent {
  final int threadId;
  final String name;

  List<TEvent> children = <TEvent>[];

  int startMicros;
  int durationMicros;

  TEvent(this.threadId, this.name);

  void setStart(int micros) {
    startMicros = micros;
  }

  void setEnd(int micros) {
    durationMicros = micros - startMicros;
  }

  int get endMicros => startMicros + (durationMicros ?? 0);

  bool get wellFormed => startMicros != null && durationMicros != null;

  void format(StringBuffer buf, String indent) {
    buf.writeln('$indent$name');
    for (TEvent child in children) {
      child.format(buf, '  $indent');
    }
  }

  @override
  String toString() => '$name, start=$startMicros duration=$durationMicros';
}

class TimelineFrame {
  int renderStart;
  int renderDuration;

  int rastereizeStart;
  int rastereizeDuration;

  TimelineFrame();

  int get start => renderStart ?? rastereizeStart;

  int get end {
    if (rastereizeStart != null) {
      return rastereizeStart + rastereizeDuration;
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

  void setRastereizeStart(int micros) {
    rastereizeStart = micros;
  }

  void setRastereizeEnd(int micros) {
    if (rastereizeStart != null) {
      rastereizeDuration = micros - rastereizeStart;
    }
  }

  bool get isComplete => renderDuration != null && rastereizeDuration != null;

  String get renderAsMs {
    return '${(renderDuration / 1000.0).toStringAsFixed(1)}ms';
  }

  String get gpuAsMs {
    return '${(rastereizeDuration / 1000.0).toStringAsFixed(1)}ms';
  }

  @override
  String toString() {
    return 'frame render: $renderDuration rasterize: $rastereizeDuration';
  }
}

class TimelineFrameData {
  final TimelineFrame frame;
  final List<TimelineThread> threads;
  final List<TEvent> events;

  TimelineFrameData(this.frame, this.threads, this.events);

  void printData() {
    for (TimelineThread thread in threads) {
      print('${thread.name}:');
      final StringBuffer buf = new StringBuffer();

      for (TEvent event in events) {
        if (event.threadId == thread.threadId) {
          event.format(buf, '  ');
          print(buf.toString().trimRight());
          buf.clear();
        }
      }
    }
  }

  Iterable<TEvent> eventsForThread(TimelineThread thread) {
    return events.where((TEvent event) => event.threadId == thread.threadId);
  }
}

/// A single timeline event.
class TimelineEvent {
  /// Creates a timeline event given JSON-encoded event data.
  factory TimelineEvent(Map<String, dynamic> json) {
    return new TimelineEvent._(json, json['name'], json['cat'], json['ph'],
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

  @override
  String toString() => '[$category] [$phase] $name';
}
