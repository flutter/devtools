// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../profiler/cpu_profile_model.dart';
import '../service_manager.dart';
import '../trace_event.dart';
import '../trees.dart';
import '../utils.dart';
import 'timeline_processor.dart';
import 'timeline_utils.dart';

class TimelineData {
  TimelineData({
    List<Map<String, dynamic>> traceEvents,
    List<TimelineFrame> frames,
    this.selectedFrame,
    this.selectedEvent,
    this.cpuProfileData,
    double displayRefreshRate,
    List<TimelineEvent> timelineEvents,
  })  : traceEvents = traceEvents ?? [],
        frames = frames ?? [],
        displayRefreshRate = displayRefreshRate ?? defaultRefreshRate,
        timelineEvents = timelineEvents ?? [];

  static const traceEventsKey = 'traceEvents';

  static const cpuProfileKey = 'cpuProfile';

  static const selectedEventKey = 'selectedEvent';

  static const timelineModeKey = 'timelineMode';

  static const uiKey = 'UI';

  static const rasterKey = 'Raster';

  static const unknownKey = 'Unknown';

  static const displayRefreshRateKey = 'displayRefreshRate';

  static const selectedFrameIdKey = 'selectedFrameId';

  final List<TimelineEvent> timelineEvents;

  final SplayTreeMap<String, TimelineEventGroup> eventGroups =
      SplayTreeMap(eventGroupComparator);

  /// List that will store trace events in the order we process them.
  ///
  /// These events are scrubbed so that bad data from the engine does not hinder
  /// event processing or trace viewing. When the export timeline button is
  /// clicked, this will be part of the output.
  List<Map<String, dynamic>> traceEvents = [];

  bool get isEmpty => traceEvents.isEmpty;

  TimelineEvent selectedEvent;

  CpuProfileData cpuProfileData;

  double displayRefreshRate;

  /// All frames currently visible in the timeline.
  List<TimelineFrame> frames = [];

  TimelineFrame selectedFrame;

  String get selectedFrameId => selectedFrame?.id;

  TimeRange time = TimeRange();

  /// The end timestamp for the data in this timeline.
  ///
  /// Track it here so that we can cache the value as we add timeline events,
  /// and eventually set [time.end] to this value after the data is processed.
  int get endTimestampMicros => _endTimestampMicros;
  int _endTimestampMicros = -1;

  void initializeEventGroups() {
    for (TimelineEvent event in timelineEvents) {
      eventGroups.putIfAbsent(
          computeEventGroupKey(event), () => TimelineEventGroup())
        ..addEventAtCalculatedRow(event);
    }
  }

  void addTimelineEvent(TimelineEvent event) {
    assert(event.isWellFormedDeep);
    timelineEvents.add(event);
    _endTimestampMicros = math.max(_endTimestampMicros, event.maxEndMicros);
  }

  bool hasCpuProfileData() {
    return cpuProfileData != null && cpuProfileData.stackFrames.isNotEmpty;
  }

  void clear() {
    traceEvents.clear();
    selectedEvent = null;
    cpuProfileData = null;
    timelineEvents.clear();
    eventGroups.clear();
    time = TimeRange();
    _endTimestampMicros = -1;
    frames.clear();
    selectedFrame = null;
  }

  // TODO(kenz): simplify this comparator if possible.
  @visibleForTesting
  static int eventGroupComparator(String a, String b) {
    if (a == b) return 0;

    // Order Unknown buckets last.
    if (a == unknownKey) return 1;
    if (b == unknownKey) return -1;

    // Order the Raster event bucket after the UI event bucket.
    if ((a == uiKey && b == rasterKey) || (a == rasterKey && b == uiKey)) {
      return -1 * a.compareTo(b);
    }

    // Order non-UI and non-raster buckets after the UI / Raster buckets.
    if (a == uiKey || a == rasterKey) return -1;
    if (b == uiKey || b == rasterKey) return 1;

    // Alphabetize all other buckets.
    return a.compareTo(b);
  }

  Map<String, dynamic> get json => {
        selectedFrameIdKey: selectedFrame?.id,
        displayRefreshRateKey: displayRefreshRate,
        traceEventsKey: traceEvents,
        cpuProfileKey: cpuProfileData?.json ?? {},
        selectedEventKey: selectedEvent?.json ?? {},
      };
}

// TODO(kenz): add tests for this class.
class TimelineEventGroup {
  /// At each index in the list, this stores row data for the row at index.
  ///
  /// We store data by row within the group in order to display events with
  /// overlapping timestamps in the flame chart UI. This allows us to reuse
  /// space where possible and avoid collisions.  We will draw overlapping
  /// events on a new flame chart row.
  ///
  /// If we have events A, B, C, and D, where all belong in a single
  /// [TimelineEventGroup] but some overlap, the UI will look
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
  final rows = <TimelineRowData>[];

  final rowIndexForEvent = <TimelineEvent, int>{};

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
        rows.add(TimelineRowData());
      }
    }

    for (int i = 0; i < event.displayDepth; i++) {
      final displayRow = event.displayRows[i];
      for (var e in displayRow) {
        rows[row + i].events.add(e);
        rowIndexForEvent[e] = row + i;
        if (e.time.end >
            (rows[row + i].lastEvent?.time?.end ?? const Duration())) {
          rows[row + i].lastEvent = e;
        }
      }
    }
  }
}

class TimelineRowData {
  /// Timeline events that will be displayed in this row in a visualization of a
  /// [TimelineEventGroup].
  final List<TimelineEvent> events = [];

  /// The last event for this row, where last means the event has the latest end
  /// time in the row.
  ///
  /// The most recently added event for the row is not guaranteed to be the last
  /// event for the row, which is why we cannot just call [events.last] to get
  /// [lastEvent].
  TimelineEvent lastEvent;
}

class OfflineTimelineData extends TimelineData {
  OfflineTimelineData._({
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

  static OfflineTimelineData parse(Map<String, dynamic> json) {
    final List<dynamic> traceEvents =
        (json[TimelineData.traceEventsKey] ?? []).cast<Map<String, dynamic>>();

    final Map<String, dynamic> cpuProfileJson =
        json[TimelineData.cpuProfileKey] ?? {};
    final CpuProfileData cpuProfileData =
        cpuProfileJson.isNotEmpty ? CpuProfileData.parse(cpuProfileJson) : null;

    final String selectedFrameId = json[TimelineData.selectedFrameIdKey];

    final Map<String, dynamic> selectedEventJson =
        json[TimelineData.selectedEventKey] ?? {};
    final OfflineTimelineEvent selectedEvent = selectedEventJson.isNotEmpty
        ? OfflineTimelineEvent(
            (selectedEventJson[TimelineEvent.firstTraceKey] ?? {})
                .cast<String, dynamic>())
        : null;

    final double displayRefreshRate =
        json[TimelineData.displayRefreshRateKey] ?? defaultRefreshRate;

    return OfflineTimelineData._(
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

  /// Creates a new instance of [OfflineTimelineData] with references to the
  /// same objects contained in this instance.
  ///
  /// This is not a deep copy. We are not modifying the before-mentioned
  /// objects, only pointing our reference variables at different objects.
  /// Therefore, we do not need to store a copy of all these objects (and the
  /// objects they contain) in memory.
  OfflineTimelineData shallowClone() {
    return OfflineTimelineData._(
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
/// * [rasterEventFlow] : flow of events showing the Raster work for the frame.
class TimelineFrame {
  TimelineFrame(this.id);

  final String id;

  /// Event flows for the UI and Raster work for the frame.
  final List<SyncTimelineEvent> eventFlows = List.generate(2, (_) => null);

  /// Flow of events describing the UI work for the frame.
  SyncTimelineEvent get uiEventFlow => eventFlows[TimelineEventType.ui.index];

  /// Flow of events describing the Raster work for the frame.
  SyncTimelineEvent get rasterEventFlow =>
      eventFlows[TimelineEventType.raster.index];

  /// Whether the frame is ready for the timeline.
  ///
  /// A frame is ready once it has both required event flows as well as
  /// [_pipelineItemStartTime] and [_pipelineItemEndTime].
  bool get isReadyForTimeline {
    return uiEventFlow != null &&
        rasterEventFlow != null &&
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

  int get rasterDuration => rasterEventFlow?.time?.duration?.inMicroseconds;

  double get rasterDurationMs =>
      rasterDuration != null ? rasterDuration / 1000 : null;

  CpuProfileData cpuProfileData;

  void setEventFlow(SyncTimelineEvent event, {TimelineEventType type}) {
    type ??= event?.type;
    if (type == TimelineEventType.ui) {
      time.start = event?.time?.start;
    }
    if (type == TimelineEventType.raster) {
      time.end = event?.time?.end;
    }
    eventFlows[type.index] = event;
    event?.frameId = id;
  }

  TimelineEvent findTimelineEvent(TimelineEvent event) {
    if (event.type == TimelineEventType.ui ||
        event.type == TimelineEventType.raster) {
      return eventFlows[event.type.index].firstChildWithCondition(
          (e) => e.name == event.name && e.time == event.time);
    }
    return null;
  }

  @override
  String toString() {
    return 'Frame $id - $time, ui: ${uiEventFlow.time}, '
        'raster: ${rasterEventFlow.time}';
  }
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

  String get groupKey => traceEvents.first.event.args['filterKey'];

  Map<String, dynamic> get beginTraceEventJson => traceEvents.first.json;

  Map<String, dynamic> get endTraceEventJson =>
      traceEvents.length > 1 ? traceEvents.last.json : null;

  bool get isUiEvent => type == TimelineEventType.ui;

  bool get isRasterEvent => type == TimelineEventType.raster;

  bool get isAsyncEvent => type == TimelineEventType.async;

  bool get isAsyncInstantEvent =>
      traceEvents.first.event.phase == TraceEvent.asyncInstantPhase;

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
      (TimelineEvent event) => event.name.contains(uiEventName));

  bool get isRasterEventFlow => subtreeHasNodeWithCondition(
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
