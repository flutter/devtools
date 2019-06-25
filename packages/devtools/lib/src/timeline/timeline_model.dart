// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:meta/meta.dart';

import '../trees.dart';
import '../utils.dart';
import 'cpu_profile_model.dart';
import 'timeline_controller.dart';

/// Data model for DevTools Timeline.
class TimelineData {
  TimelineData({
    List<Map<String, dynamic>> traceEvents,
    List<TimelineFrame> frames,
    this.selectedFrame,
    this.selectedEvent,
    this.cpuProfileData,
  })  : traceEvents = traceEvents ?? [],
        frames = frames ?? [];

  static const traceEventsKey = 'traceEvents';
  static const cpuProfileKey = 'cpuProfile';
  static const selectedEventKey = 'selectedEvent';
  static const devToolsScreenKey = 'dartDevToolsScreen';

  /// List that will store trace events in the order we process them.
  ///
  /// These events are scrubbed so that bad data from the engine does not hinder
  /// event processing or trace viewing. When the export timeline button is
  /// clicked, this will be part of the output.
  List<Map<String, dynamic>> traceEvents = [];

  /// All frames currently visible in the timeline.
  List<TimelineFrame> frames = [];

  TimelineFrame selectedFrame;

  TimelineEvent selectedEvent;

  CpuProfileData cpuProfileData;

  Map<String, dynamic> get json => {
        traceEventsKey: traceEvents,
        cpuProfileKey: cpuProfileData?.json ?? {},
        selectedEventKey: selectedEvent?.json ?? {},
        devToolsScreenKey: timelineScreenId,
      };

  void clear() {
    traceEvents.clear();
    frames.clear();
    selectedFrame = null;
    selectedEvent = null;
    cpuProfileData = null;
  }
}

class OfflineTimelineData extends TimelineData {
  OfflineTimelineData._({
    List<Map<String, dynamic>> traceEvents,
    List<TimelineFrame> frames,
    TimelineFrame selectedFrame,
    TimelineEvent selectedEvent,
    CpuProfileData cpuProfileData,
  }) : super(
          traceEvents: traceEvents,
          frames: frames,
          selectedFrame: selectedFrame,
          selectedEvent: selectedEvent,
          cpuProfileData: cpuProfileData,
        );

  static OfflineTimelineData parse(Map<String, dynamic> json) {
    final List<dynamic> traceEvents =
        (json[TimelineData.traceEventsKey] ?? []).cast<Map<String, dynamic>>();

    final Map<String, dynamic> cpuProfileJson =
        json[TimelineData.cpuProfileKey] ?? {};
    final CpuProfileData cpuProfileData =
        cpuProfileJson.isNotEmpty ? CpuProfileData.parse(cpuProfileJson) : null;

    final Map<String, dynamic> selectedEventJson =
        json[TimelineData.selectedEventKey] ?? {};
    final OfflineTimelineEvent selectedEvent = selectedEventJson.isNotEmpty
        ? OfflineTimelineEvent(
            selectedEventJson[TimelineEvent.eventNameKey],
            selectedEventJson[TimelineEvent.eventTypeKey],
            selectedEventJson[TimelineEvent.eventStartTimeKey],
            selectedEventJson[TimelineEvent.eventDurationKey],
          )
        : null;

    return OfflineTimelineData._(
      traceEvents: traceEvents,
      selectedEvent: selectedEvent,
      cpuProfileData: cpuProfileData,
    );
  }

  bool get isEmpty => traceEvents.isEmpty;

  /// Creates a new instance of [OfflineTimelineData] with references to the
  /// same objects contained in this instance ([traceEvents], [frames],
  /// [selectedFrame], [selectedEvent], [cpuProfileData]).
  ///
  /// This is not a deep copy. We are not modifying the before-mentioned
  /// objects, only pointing our reference variables at different objects.
  /// Therefore, we do not need to store a copy of all these objects (and the
  /// objects they contain) in memory.
  OfflineTimelineData copy() {
    return OfflineTimelineData._(
      traceEvents: traceEvents,
      frames: frames,
      selectedFrame: selectedFrame,
      selectedEvent: selectedEvent,
      cpuProfileData: cpuProfileData,
    );
  }
}

/// Wrapper class for [TimelineEvent] that only includes information we need for
/// importing and exporting snapshots.
///
/// * name
/// * start time
/// * duration
///
/// We extend TimelineEvent so that our CPU profiler code requiring a selected
/// timeline event will work as it does when we are not loading from offline.
class OfflineTimelineEvent extends TimelineEvent {
  OfflineTimelineEvent(
      String name, String eventType, int startMicros, int durationMicros)
      : super(TraceEventWrapper(
          TraceEvent({
            TraceEvent.nameKey: name,
            TraceEvent.timestampKey: startMicros,
            TraceEvent.durationKey: durationMicros,
            TraceEvent.argsKey: {TraceEvent.typeKey: 'ui'},
          }),
          0, // 0 is an arbitrary value for [TraceEventWrapper.timeReceived].
        )) {
    time.end = Duration(microseconds: startMicros + durationMicros);
    type = eventType == TimelineEventType.ui.toString()
        ? TimelineEventType.ui
        : TimelineEventType.gpu;
  }
}

/// Data describing a single frame.
///
/// Each TimelineFrame should have 2 distinct pieces of data:
/// * [uiEventFlow] : flow of events showing the UI work for the frame.
/// * [gpuEventFlow] : flow of events showing the GPU work for the frame.
class TimelineFrame {
  TimelineFrame(this.id);

  // TODO(kenzie): we should query the device for targetFps at some point.
  static const targetFps = 60.0;

  static const targetMaxDuration = 1000.0 / targetFps;

  final String id;

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

  final Completer cpuProfileReady = Completer();

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

  CpuProfileData cpuProfileData;

  void setEventFlow(TimelineEvent event, {TimelineEventType type}) {
    type ??= event?.type;
    if (type == TimelineEventType.ui) {
      time.start = event?.time?.start;
    }
    if (type == TimelineEventType.gpu) {
      time.end = event?.time?.end;
    }
    eventFlows[type.index] = event;
    event?.frameId = id;
  }

  @override
  String toString() {
    return 'Frame $id - $time, ui: ${uiEventFlow.time}, '
        'gpu: ${gpuEventFlow.time}';
  }
}

enum TimelineEventType {
  ui,
  gpu,
  unknown,
}

class TimelineEvent extends TreeNode<TimelineEvent> {
  TimelineEvent(TraceEventWrapper firstTraceEvent)
      : traceEvents = [firstTraceEvent],
        type = firstTraceEvent.event.type {
    time.start = Duration(microseconds: firstTraceEvent.event.timestampMicros);
  }

  static const eventNameKey = 'name';
  static const eventTypeKey = 'type';
  static const eventStartTimeKey = 'startMicros';
  static const eventDurationKey = 'durationMicros';

  /// Trace events associated with this [TimelineEvent].
  ///
  /// There will either be one entry in the list (for DurationComplete events)
  /// or two (one for the associated DurationBegin event and one for the
  /// associated DurationEnd event).
  final List<TraceEventWrapper> traceEvents;

  TimelineEventType type;

  TimeRange time = TimeRange();

  String get frameId => _frameId ?? root._frameId;

  String _frameId;

  set frameId(String id) => _frameId = id;

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

  @override
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
    root.format(buf, indent);
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

  Map<String, dynamic> get json {
    return {
      eventNameKey: name,
      eventTypeKey: type.toString(),
      eventStartTimeKey: time.start.inMicroseconds,
      eventDurationKey: time.duration.inMicroseconds,
    };
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
      : name = json[nameKey],
        category = json[categoryKey],
        phase = json[phaseKey],
        processId = json[processIdKey],
        threadId = json[threadIdKey],
        duration = json[durationKey],
        timestampMicros = json[timestampKey],
        args = json[argsKey];

  static const nameKey = 'name';
  static const categoryKey = 'cat';
  static const phaseKey = 'ph';
  static const processIdKey = 'pid';
  static const threadIdKey = 'tid';
  static const durationKey = 'dur';
  static const timestampKey = 'ts';
  static const argsKey = 'args';
  static const typeKey = 'type';
  static const idKey = 'id';
  static const scopeKey = 'scope';

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
  dynamic get id => json[idKey];

  /// An optional scope string can be specified to avoid id conflicts, in which
  /// case we consider events with the same category, scope, and id as events
  /// from the same event tree.
  String get scope => json[scopeKey];

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
      if (args[typeKey] == 'ui') {
        _type = TimelineEventType.ui;
      } else if (args[typeKey] == 'gpu') {
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
  String toString() => '$type event [$idKey: $id] [$phaseKey: $phase] '
      '$name - [$timestampKey: $timestampMicros] [$durationKey: $duration]';
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
