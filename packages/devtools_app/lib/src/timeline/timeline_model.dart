// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../profiler/cpu_profile_model.dart';
import '../service_manager.dart';
import '../trees.dart';
import '../utils.dart';
import 'timeline_controller.dart';

/// Data model for DevTools Timeline.
class FrameBasedTimelineData extends TimelineData {
  FrameBasedTimelineData({
    List<Map<String, dynamic>> traceEvents,
    List<TimelineFrame> frames,
    this.selectedFrame,
    TimelineEvent selectedEvent,
    CpuProfileData cpuProfileData,
    double displayRefreshRate,
  })  : frames = frames ?? [],
        displayRefreshRate = displayRefreshRate ?? defaultRefreshRate,
        super(
          TimelineMode.frameBased,
          traceEvents: traceEvents ?? [],
          selectedEvent: selectedEvent,
          cpuProfileData: cpuProfileData,
        );

  static const displayRefreshRateKey = 'displayRefreshRate';

  static const selectedFrameIdKey = 'selectedFrameId';

  double displayRefreshRate;

  /// All frames currently visible in the timeline.
  List<TimelineFrame> frames = [];

  TimelineFrame selectedFrame;

  String get selectedFrameId => selectedFrame?.id;

  @override
  Map<String, dynamic> get json => {
        selectedFrameIdKey: selectedFrame?.id,
        displayRefreshRateKey: displayRefreshRate,
      }..addAll(super.json);

  @override
  int get displayDepth =>
      selectedFrame.uiEventFlow.depth + selectedFrame.gpuEventFlow.depth;

  @override
  void clear() {
    super.clear();
    frames.clear();
    selectedFrame = null;
  }
}

class FullTimelineData extends TimelineData {
  FullTimelineData({
    List<Map<String, dynamic>> traceEvents,
    TimelineEvent selectedEvent,
    CpuProfileData cpuProfileData,
    List<TimelineEvent> timelineEvents,
  })  : timelineEvents = timelineEvents ?? [],
        super(
          TimelineMode.full,
          traceEvents: traceEvents ?? [],
          selectedEvent: selectedEvent,
          cpuProfileData: cpuProfileData,
        );

  static const uiKey = 'UI';

  static const gpuKey = 'GPU';

  static const unknownKey = 'Unknown';

  final List<TimelineEvent> timelineEvents;

  final SplayTreeMap<String, FullTimelineEventGroup> eventGroups =
      SplayTreeMap(eventGroupComparator);

  TimeRange time = TimeRange();

  /// The end timestamp for the data in this timeline.
  ///
  /// Track it here so that we can cache the value as we add timeline events,
  /// and eventually set [time.end] to this value after the data is processed.
  int get endTimestampMicros => _endTimestampMicros;
  int _endTimestampMicros = -1;

  /// Returns the number of rows needed to display this data.
  ///
  /// This factors in offsets necessary to display overlapping events.
  @override
  int get displayDepth {
    if (_displayDepth != null) return _displayDepth;

    if (eventGroups.isEmpty) {
      initializeEventGroups();
    }

    int depth = 0;
    for (var eventGroup in eventGroups.values) {
      depth += eventGroup.displayDepth;
    }
    return depth;
  }

  int _displayDepth;

  void initializeEventGroups() {
    timelineEvents.sort((a, b) =>
        a.time.start.inMicroseconds.compareTo(b.time.start.inMicroseconds));
    for (TimelineEvent event in timelineEvents) {
      eventGroups.putIfAbsent(
          _computeEventGroupKey(event), () => FullTimelineEventGroup())
        ..addEventAtCalculatedRow(event);
    }
  }

  void addTimelineEvent(TimelineEvent event) {
    assert(event.isWellFormedDeep);
    timelineEvents.add(event);
    _endTimestampMicros = math.max(_endTimestampMicros, event.maxEndMicros);
  }

  String _computeEventGroupKey(TimelineEvent event) {
    if (event.isAsyncEvent) {
      return event.name;
    } else if (event.isUiEvent) {
      return uiKey;
    } else if (event.isGpuEvent) {
      return gpuKey;
    } else {
      return unknownKey;
    }
  }

  @override
  void clear() {
    super.clear();
    timelineEvents.clear();
    eventGroups.clear();
    time = TimeRange();
    _displayDepth = null;
    _endTimestampMicros = -1;
  }

  // TODO(kenz): simplify this comparator if possible.
  @visibleForTesting
  static int eventGroupComparator(String a, String b) {
    if (a == b) return 0;

    // Order Unknown buckets last.
    if (a == unknownKey) return 1;
    if (b == unknownKey) return -1;

    // Order the GPU event bucket after the UI event bucket.
    if ((a == uiKey && b == gpuKey) || (a == gpuKey && b == uiKey)) {
      return -1 * a.compareTo(b);
    }

    // Order non-UI and non-GPU buckets before the UI / GPU buckets.
    if (a == uiKey || a == gpuKey) return 1;
    if (b == uiKey || b == gpuKey) return -1;

    // Alphabetize all other buckets.
    return a.compareTo(b);
  }
}

// TODO(kenz): add tests for this class.
class FullTimelineEventGroup {
  /// At each index in the list, this stores row data for the row at index.
  ///
  /// We store data by row within the group in order to display events with
  /// overlapping timestamps in the flame chart UI. This allows us to reuse
  /// space where possible and avoid collisions.  We will draw overlapping
  /// events on a new flame chart row.
  ///
  /// If we have events A, B, C, and D, where all belong in a single
  /// [FullTimelineEventGroup] but some overlap, the UI will look
  /// like this:
  ///
  ///    [timeline_event_A]    [timeline_event_C]    <-- row 0
  ///               [timeline_event_B]               <-- row 1
  ///                            [timeline_event_D]  <-- row 2
  ///
  /// The contents of [eventsByRow] would look like this:
  /// [
  ///   [timeline_event_A, timeline_event_C],
  ///   [timeline_event_B],
  ///   [timeline_event_D],
  /// ]
  final rows = <FullTimelineRowData>[];

  int get displayDepth => rows.length;

  // TODO(kenz): prevent guideline "elbows" from overlapping other events.
  void addEventAtCalculatedRow(TimelineEvent event, {int displayRow = 0}) {
    final currentLargestRowIndex = rows.length;
    while (displayRow < currentLargestRowIndex) {
      // Ensure that [event] and its children do not overlap with events at all
      // current offsets.
      final eventFitsAtDisplayRow = _eventFitsAtDisplayRow(
        event,
        displayRow,
        currentLargestRowIndex,
      );
      if (eventFitsAtDisplayRow) break;
      displayRow++;
    }
    _addEventAtDisplayRow(event, row: displayRow);
  }

  bool _eventFitsAtDisplayRow(
    TimelineEvent event,
    int displayRow,
    int currentLargestRowIndex,
  ) {
    final maxLevelToVerify =
        math.min(event.displayDepth, currentLargestRowIndex - displayRow);
    for (int level = 0; level < maxLevelToVerify; level++) {
      final lastEventAtLevel = displayRow + level < rows.length
          ? rows[displayRow + level].lastEvent
          : null;
      final firstNewEventAtLevel = event.displayRows[level].safeFirst;
      if (lastEventAtLevel != null && firstNewEventAtLevel != null) {
        // Events overlap one another, so [event] does not fit at [displayRow].
        if (lastEventAtLevel.time.overlaps(firstNewEventAtLevel.time)) {
          return false;
        }

        // [firstNewEventAtLevel] ends before [lastEventAtLevel] begins, so
        // [event] does not fit at [displayRow].
        if (firstNewEventAtLevel.time.end < lastEventAtLevel.time.start) {
          return false;
        }
      }
    }
    return true;
  }

  void _addEventAtDisplayRow(TimelineEvent event, {@required int row}) {
    if (row + event.displayDepth >= rows.length) {
      for (int i = rows.length; i < row + event.displayDepth; i++) {
        rows.add(FullTimelineRowData());
      }
    }

    for (int i = 0; i < event.displayDepth; i++) {
      final displayRow = event.displayRows[i];
      for (var e in displayRow) {
        rows[row + i].events.add(e);
        if (e.time.end >
            (rows[row + i].lastEvent?.time?.end ?? const Duration())) {
          rows[row + i].lastEvent = e;
        }
      }
    }
  }
}

class FullTimelineRowData {
  /// Timeline events that will be displayed in this row in a visualization of a
  /// [FullTimelineEventGroup].
  final List<TimelineEvent> events = [];

  /// The last event for this row, where last means the event has the latest end
  /// time in the row.
  ///
  /// The most recently added event for the row is not guaranteed to be the last
  /// event for the row, which is why we cannot just call [events.last] to get
  /// [lastEvent].
  TimelineEvent lastEvent;
}

abstract class TimelineData {
  TimelineData(
    this.timelineMode, {
    List<Map<String, dynamic>> traceEvents,
    this.selectedEvent,
    this.cpuProfileData,
  }) : traceEvents = traceEvents ?? [];

  static const traceEventsKey = 'traceEvents';

  static const cpuProfileKey = 'cpuProfile';

  static const selectedEventKey = 'selectedEvent';

  static const timelineModeKey = 'timelineMode';

  static const devToolsScreenKey = 'dartDevToolsScreen';

  final TimelineMode timelineMode;

  /// List that will store trace events in the order we process them.
  ///
  /// These events are scrubbed so that bad data from the engine does not hinder
  /// event processing or trace viewing. When the export timeline button is
  /// clicked, this will be part of the output.
  List<Map<String, dynamic>> traceEvents = [];

  bool get isEmpty => traceEvents.isEmpty;

  TimelineEvent selectedEvent;

  CpuProfileData cpuProfileData;

  Map<String, dynamic> get json => {
        traceEventsKey: traceEvents,
        cpuProfileKey: cpuProfileData?.json ?? {},
        selectedEventKey: selectedEvent?.json ?? {},
        timelineModeKey: timelineMode.toString(),
        devToolsScreenKey: timelineScreenId,
      };

  int get displayDepth;

  void clear() {
    traceEvents.clear();
    selectedEvent = null;
    cpuProfileData = null;
  }

  bool hasCpuProfileData() {
    return cpuProfileData != null && cpuProfileData.stackFrames.isNotEmpty;
  }
}

class OfflineFrameBasedTimelineData extends FrameBasedTimelineData
    with OfflineData<OfflineFrameBasedTimelineData> {
  OfflineFrameBasedTimelineData._({
    List<Map<String, dynamic>> traceEvents,
    List<TimelineFrame> frames,
    TimelineFrame selectedFrame,
    String selectedFrameId,
    TimelineEvent selectedEvent,
    double displayRefreshRate,
    CpuProfileData cpuProfileData,
  })  : _selectedFrameId = selectedFrameId,
        super(
          traceEvents: traceEvents,
          frames: frames,
          selectedFrame: selectedFrame,
          selectedEvent: selectedEvent,
          displayRefreshRate: displayRefreshRate,
          cpuProfileData: cpuProfileData,
        );

  static OfflineFrameBasedTimelineData parse(Map<String, dynamic> json) {
    final List<dynamic> traceEvents =
        (json[TimelineData.traceEventsKey] ?? []).cast<Map<String, dynamic>>();

    final Map<String, dynamic> cpuProfileJson =
        json[TimelineData.cpuProfileKey] ?? {};
    final CpuProfileData cpuProfileData =
        cpuProfileJson.isNotEmpty ? CpuProfileData.parse(cpuProfileJson) : null;

    final String selectedFrameId =
        json[FrameBasedTimelineData.selectedFrameIdKey];

    final Map<String, dynamic> selectedEventJson =
        json[TimelineData.selectedEventKey] ?? {};
    final OfflineTimelineEvent selectedEvent = selectedEventJson.isNotEmpty
        ? OfflineTimelineEvent(
            (selectedEventJson[TimelineEvent.firstTraceKey] ?? {})
                .cast<String, dynamic>())
        : null;

    final double displayRefreshRate =
        json[FrameBasedTimelineData.displayRefreshRateKey] ??
            defaultRefreshRate;

    return OfflineFrameBasedTimelineData._(
      traceEvents: traceEvents,
      selectedFrameId: selectedFrameId,
      selectedEvent: selectedEvent,
      displayRefreshRate: displayRefreshRate,
      cpuProfileData: cpuProfileData,
    );
  }

  @override
  String get selectedFrameId => _selectedFrameId;
  final String _selectedFrameId;

  /// Creates a new instance of [OfflineFrameBasedTimelineData] with references to the
  /// same objects contained in this instance.
  ///
  /// This is not a deep copy. We are not modifying the before-mentioned
  /// objects, only pointing our reference variables at different objects.
  /// Therefore, we do not need to store a copy of all these objects (and the
  /// objects they contain) in memory.
  @override
  OfflineFrameBasedTimelineData shallowClone() {
    return OfflineFrameBasedTimelineData._(
      traceEvents: traceEvents,
      frames: frames,
      selectedFrame: selectedFrame,
      selectedFrameId: selectedFrameId,
      selectedEvent: selectedEvent,
      displayRefreshRate: displayRefreshRate,
      cpuProfileData: cpuProfileData,
    );
  }
}

class OfflineFullTimelineData extends FullTimelineData
    with OfflineData<OfflineFullTimelineData> {
  OfflineFullTimelineData._({
    List<Map<String, dynamic>> traceEvents,
    TimelineEvent selectedEvent,
    CpuProfileData cpuProfileData,
  }) : super(
          traceEvents: traceEvents,
          selectedEvent: selectedEvent,
          cpuProfileData: cpuProfileData,
        );

  static OfflineFullTimelineData parse(Map<String, dynamic> json) {
    final List<dynamic> traceEvents =
        List.from(json[TimelineData.traceEventsKey] ?? [])
            .cast<Map<String, dynamic>>();

    final Map<String, dynamic> cpuProfileJson =
        json[TimelineData.cpuProfileKey] ?? {};
    final CpuProfileData cpuProfileData =
        cpuProfileJson.isNotEmpty ? CpuProfileData.parse(cpuProfileJson) : null;

    final Map<String, dynamic> selectedEventJson =
        json[TimelineData.selectedEventKey] ?? {};
    final OfflineTimelineEvent selectedEvent = selectedEventJson.isNotEmpty
        ? OfflineTimelineEvent(
            (selectedEventJson[TimelineEvent.firstTraceKey] ?? {})
                .cast<String, dynamic>())
        : null;

    return OfflineFullTimelineData._(
      traceEvents: traceEvents,
      selectedEvent: selectedEvent,
      cpuProfileData: cpuProfileData,
    );
  }

  /// Creates a new instance of [OfflineFullTimelineData] with references to the
  /// same objects contained in this instance.
  ///
  /// This is not a deep clone. We are not modifying the before-mentioned
  /// objects, only pointing our reference variables at different objects.
  /// Therefore, we do not need to store a copy of all these objects (and the
  /// objects they contain) in memory.
  @override
  OfflineFullTimelineData shallowClone() {
    return OfflineFullTimelineData._(
      traceEvents: traceEvents,
      selectedEvent: selectedEvent,
      cpuProfileData: cpuProfileData,
    );
  }
}

mixin OfflineData<T extends TimelineData> on TimelineData {
  T shallowClone();
}

/// Wrapper class for [TimelineEvent] that only includes information we need for
/// importing and exporting snapshots.
///
/// * name
/// * start time
/// * duration
/// * type
///
/// We extend TimelineEvent so that our CPU profiler code requiring a selected
/// timeline event will work as it does when we are not loading from offline.
class OfflineTimelineEvent extends TimelineEvent {
  OfflineTimelineEvent(Map<String, dynamic> firstTrace)
      : super(TraceEventWrapper(
          TraceEvent(firstTrace),
          0, // 0 is an arbitrary value for [TraceEventWrapper.timeReceived].
        )) {
    time.end = Duration(
        microseconds: firstTrace[TraceEvent.timestampKey] +
            firstTrace[TraceEvent.durationKey]);
    type = TimelineEventType.values.firstWhere(
        (t) =>
            t.toString() ==
            firstTrace[TraceEvent.argsKey][TraceEvent.typeKey].toString(),
        orElse: () => TimelineEventType.unknown);
  }

  // The following methods should never be called on an instance of
  // [OfflineTimelineEvent]. The intended use for this class is to wrap a
  // [TimelineEvent] for the purpose of importing and exporting timeline
  // snapshots.

  @override
  bool couldBeParentOf(TimelineEvent e) {
    throw UnimplementedError('This method should never be called for an '
        'instance of OfflineTimelineEvent');
  }

  @override
  int get maxEndMicros =>
      throw UnimplementedError('This method should never be called for an '
          'instance of OfflineTimelineEvent');

  @override
  List<List<TimelineEvent>> _calculateDisplayRows() =>
      throw UnimplementedError('This method should never be called for an '
          'instance of OfflineTimelineEvent');
}

/// Data describing a single frame.
///
/// Each TimelineFrame should have 2 distinct pieces of data:
/// * [uiEventFlow] : flow of events showing the UI work for the frame.
/// * [gpuEventFlow] : flow of events showing the GPU work for the frame.
class TimelineFrame {
  TimelineFrame(this.id);

  final String id;

  /// Marks whether this frame has been added to the timeline.
  ///
  /// This should only be set once.
  bool get addedToTimeline => _addedToTimeline;

  bool _addedToTimeline;

  set addedToTimeline(bool v) {
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

  int get uiDuration => uiEventFlow?.time?.duration?.inMicroseconds;

  double get uiDurationMs => uiDuration != null ? uiDuration / 1000 : null;

  int get gpuDuration => gpuEventFlow?.time?.duration?.inMicroseconds;

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

  TimelineEvent findTimelineEvent(TimelineEvent event) {
    if (event.type == TimelineEventType.ui ||
        event.type == TimelineEventType.gpu) {
      return eventFlows[event.type.index].firstChildWithCondition(
          (e) => e.name == event.name && e.time == event.time);
    }
    return null;
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
  async,
  unknown,
}

abstract class TimelineEvent extends TreeNode<TimelineEvent> {
  TimelineEvent(TraceEventWrapper firstTraceEvent)
      : traceEvents = [firstTraceEvent],
        type = firstTraceEvent.event.type {
    time.start = Duration(microseconds: firstTraceEvent.event.timestampMicros);
  }

  static const firstTraceKey = 'firstTrace';
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

  bool get isAsyncEvent => type == TimelineEventType.async;

  bool get isWellFormed => time.start != null && time.end != null;

  bool get isWellFormedDeep => _isWellFormedDeep(this);

  bool _isWellFormedDeep(TimelineEvent event) {
    return !subtreeHasNodeWithCondition((e) => !e.isWellFormed);
  }

  /// Maximum end micros for the event.
  ///
  /// This value could come from the end time of [this] event or from the end
  /// time of any of its descendant events.
  int get maxEndMicros;

  /// Whether [this] event could be the parent of [e] based on criteria such as
  /// timestamps and event ids.
  bool couldBeParentOf(TimelineEvent e);

  /// Tracks the start row for the lowest visual child in the display for this
  /// TimelineEvent.
  int _lowestDisplayChildRow = 1;

  /// The child that is nearest the bottom of the visualization for this
  /// TimelineEvent.
  TimelineEvent get lowestDisplayChild => _lowestDisplayChild;
  TimelineEvent _lowestDisplayChild;

  int get displayDepth => displayRows.length;

  List<List<TimelineEvent>> _displayRows;
  List<List<TimelineEvent>> get displayRows =>
      _displayRows ??= _calculateDisplayRows();

  List<List<TimelineEvent>> _calculateDisplayRows();

  void _expandDisplayRows(int newRowLength) {
    _displayRows ??= [];
    final currentLength = _displayRows.length;
    for (int i = currentLength; i < newRowLength; i++) {
      _displayRows.add([]);
    }
  }

  void _mergeChildDisplayRows(int mergeStartLevel, TimelineEvent child) {
    assert(
      mergeStartLevel <= _displayRows.length,
      'mergeStartLevel $mergeStartLevel is greater than _displayRows.length'
      ' ${_displayRows.length}',
    );
    final childDisplayRows = child.displayRows;
    _expandDisplayRows(mergeStartLevel + childDisplayRows.length);
    for (int i = 0; i < childDisplayRows.length; i++) {
      displayRows[mergeStartLevel + i].addAll(childDisplayRows[i]);
    }
    if (mergeStartLevel >= _lowestDisplayChildRow) {
      _lowestDisplayChildRow = mergeStartLevel;
      _lowestDisplayChild = child;
    }
  }

  void addEndEvent(TraceEventWrapper eventWrapper) {
    time.end = Duration(microseconds: eventWrapper.event.timestampMicros);
    traceEvents.add(eventWrapper);
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
        parent.removeChild(parent.children.first);
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
    final modifiedTrace = Map.from(beginTraceEventJson);
    modifiedTrace[TraceEvent.argsKey]
        .addAll({TraceEvent.typeKey: type.toString()});
    if (!modifiedTrace.containsKey(TraceEvent.durationKey)) {
      modifiedTrace
          .addAll({TraceEvent.durationKey: time.duration.inMicroseconds});
    }
    return {firstTraceKey: modifiedTrace};
  }

  @visibleForTesting
  TimelineEvent deepCopy() {
    final copy = isAsyncEvent
        ? AsyncTimelineEvent(traceEvents.first)
        : SyncTimelineEvent(traceEvents.first);
    copy.time.end = time.end;
    copy.parent = parent;
    for (TimelineEvent child in children) {
      copy._addChild(child.deepCopy());
    }
    return copy;
  }

  // TODO(kenz): use DiagnosticableTreeMixin instead.
  @override
  String toString() {
    final buf = StringBuffer();
    format(buf, '  ');
    return buf.toString();
  }
}

class SyncTimelineEvent extends TimelineEvent {
  SyncTimelineEvent(TraceEventWrapper firstTraceEvent) : super(firstTraceEvent);

  bool get isUiEventFlow => subtreeHasNodeWithCondition(
      (TimelineEvent event) => event.name.contains('Engine::BeginFrame'));

  bool get isGpuEventFlow => subtreeHasNodeWithCondition(
      (TimelineEvent event) => event.name.contains('PipelineConsume'));

  @override
  int get maxEndMicros => time.end.inMicroseconds;

  @override
  List<List<TimelineEvent>> _calculateDisplayRows() {
    assert(_displayRows == null);
    _expandDisplayRows(depth);

    _displayRows[0].add(this);
    for (final child in children) {
      _mergeChildDisplayRows(1, child);
    }
    return _displayRows;
  }

  @override
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
}

// TODO(kenz): calculate and store async guidelines here instead of in the UI
// code.
class AsyncTimelineEvent extends TimelineEvent {
  AsyncTimelineEvent(TraceEventWrapper firstTraceEvent)
      : asyncId = firstTraceEvent.event.id,
        parentId = firstTraceEvent.event.args[parentIdKey],
        super(firstTraceEvent) {
    type = TimelineEventType.async;
  }

  static const parentIdKey = 'parentId';

  final String asyncId;

  /// Unique id for this async event's parent event.
  ///
  /// This field is not guaranteed to be non-null.
  final String parentId;

  int _maxEndMicros;
  @override
  int get maxEndMicros => _maxEndMicros ?? _calculateMaxEndMicros();

  int _calculateMaxEndMicros() {
    if (children.isEmpty) {
      return time.end.inMicroseconds;
    }
    var maxEnd = time.end.inMicroseconds;
    for (AsyncTimelineEvent child in children) {
      maxEnd = math.max(maxEnd, child._calculateMaxEndMicros());
    }
    return _maxEndMicros = maxEnd;
  }

  @override
  List<List<TimelineEvent>> _calculateDisplayRows() {
    assert(_displayRows == null);
    _expandDisplayRows(1);

    const currentRow = 0;
    _displayRows[currentRow].add(this);

    const mainChildRow = currentRow + 1;
    for (int i = 0; i < children.length; i++) {
      final AsyncTimelineEvent child = children[i];
      if (i == 0 ||
          _eventFitsAtDisplayRow(child, mainChildRow, _displayRows.length)) {
        _mergeChildDisplayRows(mainChildRow, child);
      } else {
        // If [child] does not fit on the target row, add it below the current
        // deepest display row.
        _mergeChildDisplayRows(displayRows.length, child);
      }
    }
    return _displayRows;
  }

  bool _eventFitsAtDisplayRow(
    AsyncTimelineEvent event,
    int displayRow,
    int currentLargestRowIndex,
  ) {
    final maxLevelToVerify =
        math.min(event.displayDepth, currentLargestRowIndex - displayRow);
    for (int level = 0; level < maxLevelToVerify; level++) {
      final lastEventAtLevel = _displayRows[displayRow + level].safeLast;
      final firstNewEventAtLevel = event.firstChildNodeAtLevel(level);
      if (lastEventAtLevel != null && firstNewEventAtLevel != null) {
        // Events overlap one another, so [event] does not fit at [displayRow].
        if (lastEventAtLevel.time.overlaps(firstNewEventAtLevel.time)) {
          return false;
        }

        // [firstNewEventAtLevel] ends before [lastEventAtLevel] begins, so
        // [event] does not fit at [displayRow].
        if (firstNewEventAtLevel.time.end < lastEventAtLevel.time.start) {
          return false;
        }

        final lastEventParent = lastEventAtLevel.parent;
        final firstNewEventParent = firstNewEventAtLevel.parent;
        // If the two events are non-overlapping siblings and their parent ends
        // before [lastEventAtLevel], drawing a subsequent guideline from
        // [lastEventParent] to [firstNewEventAtLevel] would overlap
        // [lastEventAtLevel], so we cannot place [event] on this row.
        if (lastEventParent != null &&
            firstNewEventParent != null &&
            lastEventParent == firstNewEventParent &&
            lastEventAtLevel.time.end >= lastEventParent.time.end) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void addChild(TimelineEvent child) {
    final AsyncTimelineEvent _child = child;
    // Short circuit if we are using an explicit parentId.
    if (_child.parentId != null &&
        _child.parentId == traceEvents.first.event.id) {
      _addChild(child);
    } else {
      super.addChild(child);
    }
  }

  @override
  bool couldBeParentOf(TimelineEvent e) {
    final AsyncTimelineEvent asyncEvent = e;

    // If [asyncEvent] has an explicit parentId, use that as the truth.
    if (asyncEvent.parentId != null) return asyncId == asyncEvent.parentId;

    // Without an explicit parentId, two events must share an asyncId to be
    // part of the same event tree.
    if (asyncId != asyncEvent.asyncId) return false;

    // When two events share an asyncId, determine parent / child relationships
    // based on timestamps.
    final startTime = time.start.inMicroseconds;
    final endTime = time.end?.inMicroseconds;
    final eStartTime = e.time.start.inMicroseconds;
    final eEndTime = e.time.end?.inMicroseconds;

    if (endTime != null && eEndTime != null) {
      if (startTime == eStartTime && endTime == eEndTime) {
        return int.parse(asyncId, radix: 16) <
            int.parse(asyncEvent.asyncId, radix: 16);
      }
      return startTime <= eStartTime && endTime >= eEndTime;
    } else if (endTime != null) {
      // We don't use >= to compare [endTime] and [eStartTime] here because we
      // don't want to falsely make [this] the parent of [e]. We do not know
      // [eEndTime], meaning [e] could start at [endTime] and end later than
      // [endTime] (unless e has a duration of 0). In this case, [this] would
      // not be the parent of [e].
      return startTime <= eStartTime && endTime > eStartTime;
    } else if (startTime == eStartTime) {
      return int.parse(asyncId, radix: 16) <
          int.parse(asyncEvent.asyncId, radix: 16);
    } else {
      return startTime < eStartTime;
    }
  }

  void endAsyncEvent(TraceEventWrapper eventWrapper) {
    assert(
      asyncId == eventWrapper.event.id,
      'asyncId = $asyncId, but endEventId = ${eventWrapper.event.id}',
    );
    if (endTraceEventJson != null) {
      // This event has already ended and [eventWrapper] is a duplicate trace
      // event.
      return;
    }
    if (name == eventWrapper.event.name) {
      addEndEvent(eventWrapper);
      return;
    }

    for (AsyncTimelineEvent child in children) {
      child.endAsyncEvent(eventWrapper);
    }
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

  static const asyncBeginPhase = 'b';
  static const asyncEndPhase = 'e';
  static const asyncInstantPhase = 'n';
  static const durationBeginPhase = 'B';
  static const durationEndPhase = 'E';
  static const durationCompletePhase = 'X';
  static const flowStartPhase = 's';
  static const flowEndPhase = 'f';

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
