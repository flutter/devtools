// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../service/service_manager.dart';
import '../../shared/charts/flame_chart.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/primitives/trace_event.dart';
import '../../shared/primitives/trees.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/search.dart';
import '../profiler/cpu_profile_model.dart';
import 'panes/flutter_frames/flutter_frame_model.dart';
import 'panes/raster_stats/raster_stats_model.dart';
import 'panes/rebuild_stats/rebuild_stats_model.dart';
import 'panes/timeline_events/timeline_event_processor.dart';
import 'performance_utils.dart';

class PerformanceData {
  PerformanceData({
    List<Map<String, dynamic>>? traceEvents,
    List<FlutterFrame>? frames,
    this.selectedFrame,
    this.selectedEvent,
    this.cpuProfileData,
    this.rasterStats,
    RebuildCountModel? rebuildCountModel,
    double? displayRefreshRate,
    List<TimelineEvent>? timelineEvents,
  })  : traceEvents = traceEvents ?? <Map<String, dynamic>>[],
        frames = frames ?? <FlutterFrame>[],
        rebuildCountModel = rebuildCountModel ?? RebuildCountModel(),
        displayRefreshRate = displayRefreshRate ?? defaultRefreshRate,
        timelineEvents = timelineEvents ?? <TimelineEvent>[];

  static const traceEventsKey = traceEventsFieldName;

  static const cpuProfileKey = 'cpuProfile';

  static const rasterStatsKey = 'rasterStats';

  static const rebuildCountModelKey = 'rebuildCountModel';

  static const selectedEventKey = 'selectedEvent';

  static const uiKey = 'UI';

  static const rasterKey = 'Raster';

  static const unknownKey = 'Unknown';

  static const displayRefreshRateKey = 'displayRefreshRate';

  static const flutterFramesKey = 'flutterFrames';

  static const selectedFrameIdKey = 'selectedFrameId';

  final List<TimelineEvent> timelineEvents;

  final SplayTreeMap<String, TimelineEventGroup> eventGroups =
      SplayTreeMap(PerformanceUtils.eventGroupComparator);

  /// List that will store trace events in the order we process them.
  ///
  /// These events are scrubbed so that bad data from the engine does not hinder
  /// event processing or trace viewing. When the export timeline button is
  /// clicked, this will be part of the output.
  final List<Map<String, dynamic>> traceEvents;

  bool get isEmpty => traceEvents.isEmpty;

  TimelineEvent? selectedEvent;

  CpuProfileData? cpuProfileData;

  RasterStats? rasterStats;

  RebuildCountModel rebuildCountModel;

  double displayRefreshRate;

  /// All frames currently visible in the timeline.
  final List<FlutterFrame> frames;

  FlutterFrame? selectedFrame;

  int? get selectedFrameId => selectedFrame?.id;

  TimeRange time = TimeRange();

  /// The end timestamp for the data in this timeline.
  ///
  /// Track it here so that we can cache the value as we add timeline events,
  /// and eventually set [time.end] to this value after the data is processed.
  int get endTimestampMicros => _endTimestampMicros;
  int _endTimestampMicros = -1;

  void initializeEventGroups(
    Map<int, String> threadNamesById, {
    int startIndex = 0,
  }) {
    for (int i = startIndex; i < timelineEvents.length; i++) {
      final event = timelineEvents[i];
      eventGroups
          .putIfAbsent(
            PerformanceUtils.computeEventGroupKey(event, threadNamesById),
            () => TimelineEventGroup(),
          )
          .addEventAtCalculatedRow(event);
    }
  }

  void addTimelineEvent(TimelineEvent event) {
    assert(event.isWellFormedDeep);
    timelineEvents.add(event);
    _endTimestampMicros = math.max(_endTimestampMicros, event.maxEndMicros);
  }

  void clear() {
    traceEvents.clear();
    selectedEvent = null;
    cpuProfileData = null;
    rasterStats = null;
    timelineEvents.clear();
    eventGroups.clear();
    time = TimeRange();
    _endTimestampMicros = -1;
    frames.clear();
    selectedFrame = null;
    rebuildCountModel.clearAllCounts();
  }

  Map<String, dynamic> toJson() => {
        selectedFrameIdKey: selectedFrame?.id,
        flutterFramesKey: frames.map((frame) => frame.json).toList(),
        displayRefreshRateKey: displayRefreshRate,
        traceEventsKey: traceEvents,
        selectedEventKey: selectedEvent?.json ?? <String, dynamic>{},
        cpuProfileKey: cpuProfileData?.toJson ?? <String, dynamic>{},
        rasterStatsKey: rasterStats?.json ?? <String, dynamic>{},
        rebuildCountModelKey: rebuildCountModel.toJson(),
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

  late int earliestTimestampMicros;

  late int latestTimestampMicros;

  bool _timestampsInitialized = false;

  List<TimelineEvent> get sortedEventRoots =>
      _sortedEventRoots ??= List<TimelineEvent>.of(rowIndexForEvent.keys)
          .where((event) => event.isRoot)
          .toList()
        ..sort(
          (a, b) => a.time.start!.inMicroseconds
              .compareTo(b.time.start!.inMicroseconds),
        );
  List<TimelineEvent>? _sortedEventRoots;

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
        if (firstNewEventAtLevel.time.end! < lastEventAtLevel.time.start!) {
          return false;
        }
      }
    }
    return true;
  }

  void _addEventAtDisplayRow(TimelineEvent event, {required int row}) {
    if (row + event.displayDepth >= rows.length) {
      for (int i = rows.length; i < row + event.displayDepth; i++) {
        rows.add(TimelineRowData());
      }
    }

    for (int i = 0; i < event.displayDepth; i++) {
      final displayRow = event.displayRows[i];
      for (var e in displayRow) {
        final timeStart = e.time.start!.inMicroseconds;
        final timeEnd = e.time.end!.inMicroseconds;
        earliestTimestampMicros = _timestampsInitialized
            ? math.min(timeStart, earliestTimestampMicros)
            : timeEnd;
        latestTimestampMicros = _timestampsInitialized
            ? math.max(timeEnd, latestTimestampMicros)
            : timeEnd;
        _timestampsInitialized = true;

        rows[row + i].events.add(e);
        rowIndexForEvent[e] = row + i;
        if (e.time.end! >
            (rows[row + i].lastEvent?.time.end ?? const Duration())) {
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
  TimelineEvent? lastEvent;
}

class OfflinePerformanceData extends PerformanceData {
  OfflinePerformanceData._({
    required super.traceEvents,
    required super.frames,
    required super.selectedFrame,
    required this.selectedFrameId,
    required super.selectedEvent,
    required super.displayRefreshRate,
    required super.cpuProfileData,
    required super.rasterStats,
    required super.rebuildCountModel,
  });

  static OfflinePerformanceData parse(Map<String, Object?> json_) {
    final json = _PerformanceDataJson(json_);

    final selectedFrameId = json.selectedFrameId;
    final frames = json.frames;
    final selectedFrame =
        frames.firstWhereOrNull((frame) => frame.id == selectedFrameId);

    return OfflinePerformanceData._(
      traceEvents: json.traceEvents,
      selectedFrame: selectedFrame,
      selectedFrameId: selectedFrameId,
      frames: frames,
      selectedEvent: json.selectedEvent,
      displayRefreshRate: json.displayRefreshRate,
      cpuProfileData: json.cpuProfile,
      rasterStats: json.rasterStats,
      rebuildCountModel: json.rebuildCountModel,
    );
  }

  @override
  final int? selectedFrameId;

  /// Creates a new instance of [OfflinePerformanceData] with references to the
  /// same objects contained in this instance.
  ///
  /// This is not a deep copy. We are not modifying the before-mentioned
  /// objects, only pointing our reference variables at different objects.
  /// Therefore, we do not need to store a copy of all these objects (and the
  /// objects they contain) in memory.
  OfflinePerformanceData shallowClone() {
    return OfflinePerformanceData._(
      traceEvents: traceEvents,
      frames: frames,
      selectedFrame: selectedFrame,
      selectedFrameId: selectedFrameId,
      selectedEvent: selectedEvent,
      displayRefreshRate: displayRefreshRate,
      cpuProfileData: cpuProfileData,
      rasterStats: rasterStats,
      rebuildCountModel: rebuildCountModel,
    );
  }
}

extension type _PerformanceDataJson(Map<String, Object?> json) {
  List<Map<String, Object?>> get traceEvents =>
      (json[PerformanceData.traceEventsKey] as List? ?? [])
          .cast<Map>()
          .map((e) => e.cast<String, Object?>())
          .toList();

  CpuProfileData? get cpuProfile {
    final raw =
        (json[PerformanceData.cpuProfileKey] as Map?)?.cast<String, Object>();
    return raw == null || raw.isEmpty ? null : CpuProfileData.parse(raw);
  }

  RasterStats? get rasterStats {
    final raw =
        (json[PerformanceData.rasterStatsKey] as Map).cast<String, Object>();
    return raw.isNotEmpty ? RasterStats.parse(raw) : null;
  }

  int? get selectedFrameId => json[PerformanceData.selectedFrameIdKey] as int?;

  List<FlutterFrame> get frames =>
      (json[PerformanceData.flutterFramesKey] as List? ?? [])
          .cast<Map>()
          .map((f) => f.cast<String, dynamic>())
          .map((f) => FlutterFrame.parse(f))
          .toList();

  OfflineTimelineEvent? get selectedEvent {
    final raw = (json[PerformanceData.selectedEventKey] as Map? ?? {})
        .cast<String, dynamic>();

    if (raw.isEmpty) return null;

    return OfflineTimelineEvent(
      (raw[TimelineEvent.firstTraceKey] as Map? ?? {}).cast<String, Object>(),
    );
  }

  double get displayRefreshRate =>
      (json[PerformanceData.displayRefreshRateKey] as num?)?.toDouble() ??
      defaultRefreshRate;

  RebuildCountModel? get rebuildCountModel {
    final raw = (json[PerformanceData.rebuildCountModelKey] as Map? ?? {})
        .cast<String, dynamic>();
    return raw.isNotEmpty ? RebuildCountModel.parse(raw) : null;
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
      : super(
          TraceEventWrapper(
            TraceEvent(firstTrace),
            0, // 0 is an arbitrary value for [TraceEventWrapper.timeReceived].
          ),
        ) {
    time.end = Duration(
      microseconds: (firstTrace[TraceEvent.timestampKey] as int) +
          (firstTrace[TraceEvent.durationKey] as int),
    );
    final typeArg =
        (firstTrace[TraceEvent.argsKey] as Map)[TraceEvent.typeKey].toString();
    type = TimelineEventType.values.firstWhere(
      (t) => t.toString() == typeArg,
      orElse: () => TimelineEventType.other,
    );
  }

  // The following methods should never be called on an instance of
  // [OfflineTimelineEvent]. The intended use for this class is to wrap a
  // [TimelineEvent] for the purpose of importing and exporting timeline
  // snapshots.

  @override
  bool couldBeParentOf(TimelineEvent e) {
    throw UnimplementedError(
      'This method should never be called for an '
      'instance of OfflineTimelineEvent',
    );
  }

  @override
  int get maxEndMicros => throw UnimplementedError(
        'This method should never be called for an '
        'instance of OfflineTimelineEvent',
      );

  @override
  List<List<TimelineEvent>> _calculateDisplayRows() => throw UnimplementedError(
        'This method should never be called for an '
        'instance of OfflineTimelineEvent',
      );

  @override
  OfflineTimelineEvent shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}

abstract class TimelineEvent extends TreeNode<TimelineEvent>
    with
        SearchableDataMixin,
        TreeDataSearchStateMixin<TimelineEvent>,
        FlameChartDataMixin {
  TimelineEvent(TraceEventWrapper firstTraceEvent)
      : traceEvents = [firstTraceEvent],
        type = firstTraceEvent.event.type {
    time.start = Duration(microseconds: firstTraceEvent.event.timestampMicros!);
  }

  static const firstTraceKey = 'firstTrace';

  /// Trace events associated with this [TimelineEvent].
  ///
  /// There will either be one entry in the list (for DurationComplete events)
  /// or two (one for the associated DurationBegin event and one for the
  /// associated DurationEnd event).
  final List<TraceEventWrapper> traceEvents;

  /// Trace event wrapper id for this timeline event.
  ///
  /// We will lookup this data multiple times for a single event when forming
  /// event trees, so we cache this to improve the performance and reduce the
  /// number of calls to [List.first].
  int get traceWrapperId => _traceWrapperId ??= traceEvents.first.wrapperId;

  int? _traceWrapperId;

  TimelineEventType type;

  TimeRange time = TimeRange();

  int? get frameId => _frameId ?? root._frameId;

  int? _frameId;

  set frameId(int? id) => _frameId = id;

  String? get name => traceEvents.first.event.name;

  String? get groupKey => traceEvents.first.event.args!['filterKey'] as String?;

  Map<String, dynamic> get beginTraceEventJson => traceEvents.first.json;

  Map<String, dynamic>? get endTraceEventJson =>
      traceEvents.length > 1 ? traceEvents.last.json : null;

  bool get isUiEvent => type == TimelineEventType.ui;

  bool get isRasterEvent => type == TimelineEventType.raster;

  bool get isAsyncEvent => type == TimelineEventType.async;

  bool get isAsyncInstantEvent =>
      traceEvents.first.event.phase == TraceEvent.asyncInstantPhase;

  bool get isGCEvent =>
      traceEvents.first.event.category == TraceEvent.gcCategory;

  bool get isShaderEvent =>
      traceEvents.first.isShaderEvent || traceEvents.last.isShaderEvent;

  bool get isWellFormed => time.start != null && time.end != null;

  bool get isWellFormedDeep => _isWellFormedDeep(this);

  int? get threadId => traceEvents.first.event.threadId;

  @override
  String get tooltip => '$name - ${durationText(time.duration)}';

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
  late TimelineEvent _lowestDisplayChild;

  int get displayDepth => displayRows.length;

  late List<List<TimelineEvent>> displayRows = _calculateDisplayRows();

  List<List<TimelineEvent>> _calculateDisplayRows();

  void _expandDisplayRows({
    required List<List<TimelineEvent>> rows,
    required int newRowLength,
  }) {
    final currentLength = rows.length;
    for (int i = currentLength; i < newRowLength; i++) {
      rows.add([]);
    }
  }

  void _mergeChildDisplayRows({
    required int mergeStartLevel,
    required TimelineEvent child,
    required List<List<TimelineEvent>> rows,
  }) {
    assert(
      mergeStartLevel <= rows.length,
      'mergeStartLevel $mergeStartLevel is greater than _displayRows.length'
      ' ${rows.length}',
    );
    final childDisplayRows = child.displayRows;
    _expandDisplayRows(
      rows: rows,
      newRowLength: mergeStartLevel + childDisplayRows.length,
    );
    for (int i = 0; i < childDisplayRows.length; i++) {
      rows[mergeStartLevel + i].addAll(childDisplayRows[i]);
    }
    if (mergeStartLevel >= _lowestDisplayChildRow) {
      _lowestDisplayChildRow = mergeStartLevel;
      _lowestDisplayChild = child;
    }
  }

  void addEndEvent(TraceEventWrapper eventWrapper) {
    time.end = Duration(microseconds: eventWrapper.event.timestampMicros!);
    traceEvents.add(eventWrapper);
  }

  void maybeRemoveDuplicate() {
    void removeDuplicateHelper({required TimelineEvent parent}) {
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
      removeDuplicateHelper(parent: this);
    }
    // Remove [this] event if it is a duplicate of [parent].
    if (parent != null) {
      removeDuplicateHelper(parent: parent!);
    }
  }

  void removeChild(TimelineEvent childToRemove) {
    assert(children.contains(childToRemove));
    final List<TimelineEvent> newChildren = List.of(childToRemove.children);
    newChildren.forEach(_addChild);
    children.remove(childToRemove);
  }

  @override
  void addChild(TimelineEvent child, {int? index}) {
    assert(index == null);
    void putChildInTree(TimelineEvent root) {
      // [root] is a leaf. Add child here.
      if (root.children.isEmpty) {
        root._addChild(child);
        return;
      }

      final eventChildren = root.children.toList();

      // If [child] is the parent of some or all of the members in [_children],
      // those members will need to be reordered in the tree.
      final childrenToReorder = <TimelineEvent>[];
      for (TimelineEvent otherChild in eventChildren) {
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
      for (TimelineEvent otherChild in eventChildren.reversed) {
        if (otherChild.couldBeParentOf(child)) {
          // Recurse on [otherChild]'s subtree.
          putChildInTree(otherChild);
          return;
        }
      }

      // If we have not returned at this point, [child] belongs in
      // [root.children].
      root._addChild(child);
    }

    putChildInTree(this);
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
    final modifiedTrace = {...beginTraceEventJson}
      ..putIfAbsent(TraceEvent.durationKey, () => time.duration.inMicroseconds);
    (modifiedTrace[TraceEvent.argsKey] as Map)[TraceEvent.typeKey] =
        type.toString();
    return {firstTraceKey: modifiedTrace};
  }

  @override
  TimelineEvent shallowCopy() {
    final copy = isAsyncEvent
        ? AsyncTimelineEvent(traceEvents.first)
        : SyncTimelineEvent(traceEvents.first);
    for (int i = 1; i < traceEvents.length; i++) {
      copy.traceEvents.add(traceEvents[i]);
    }
    copy
      ..type = type
      ..time = (TimeRange()
        ..start = time.start
        ..end = time.end);
    return copy;
  }

  @visibleForTesting
  TimelineEvent deepCopy() {
    final copy = shallowCopy();
    copy.parent = parent;
    for (TimelineEvent child in children) {
      copy._addChild(child.deepCopy());
    }
    return copy;
  }

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return name!.caseInsensitiveContains(regExpSearch);
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

  int? get flutterFrameNumber {
    if (_flutterFrameNumber != null) {
      return _flutterFrameNumber;
    }
    final frameNumber =
        traceEvents.first.event.args![TraceEvent.frameNumberArg];
    return _flutterFrameNumber =
        frameNumber != null ? int.tryParse(frameNumber as String) : null;
  }

  int? _flutterFrameNumber;

  /// Whether this event is contains the flutter frame identifier for the UI
  /// thread in its trace event args.
  bool get isUiFrameIdentifier =>
      _isUiFrameIdentifier ??= name == uiEventName &&
          traceEvents.first.event.args!.containsKey(TraceEvent.frameNumberArg);

  bool? _isUiFrameIdentifier;

  /// Whether this event contains the flutter frame identifier for the Raster
  /// thread in its trace event args.
  ///
  /// We check for `name == rasterEventName` in addition to
  /// `name == rasterEventNameWithFrameNumber` so that we can load legacy traces
  /// created before https://github.com/flutter/engine/pull/32283/ landed.
  bool get isRasterFrameIdentifier => _isRasterFrameIdentifier ??=
      (name == rasterEventName || name == rasterEventNameWithFrameNumber) &&
          traceEvents.first.event.args!.containsKey(TraceEvent.frameNumberArg);

  bool? _isRasterFrameIdentifier;

  final uiFrameEvents = <SyncTimelineEvent>[];

  final rasterFrameEvents = <SyncTimelineEvent>[];

  @override
  int get maxEndMicros => time.end!.inMicroseconds;

  @override
  List<List<TimelineEvent>> _calculateDisplayRows() {
    final rows = <List<TimelineEvent>>[];
    _expandDisplayRows(rows: rows, newRowLength: depth);

    rows[0].add(this);
    for (final child in children) {
      _mergeChildDisplayRows(
        mergeStartLevel: 1,
        child: child,
        rows: rows,
      );
    }
    return rows;
  }

  @override
  bool couldBeParentOf(TimelineEvent e) {
    // TODO(kenz): consider caching start and end times in the [TimeRange] class
    // since these can be looked up many times for a single [TimeRange] object.
    final startTime = time.start!.inMicroseconds;
    final endTime = time.end?.inMicroseconds;
    final eStartTime = e.time.start!.inMicroseconds;
    final eEndTime = e.time.end?.inMicroseconds;
    final eFirstTraceId = e.traceWrapperId;

    if (endTime != null && eEndTime != null) {
      if (startTime == eStartTime && endTime == eEndTime) {
        return traceWrapperId < eFirstTraceId;
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
      return traceWrapperId < eFirstTraceId;
    } else {
      return startTime < eStartTime;
    }
  }

  @override
  SyncTimelineEvent deepCopy() {
    return super.deepCopy() as SyncTimelineEvent;
  }
}

// TODO(kenz): calculate and store async guidelines here instead of in the UI
// code.
class AsyncTimelineEvent extends TimelineEvent {
  AsyncTimelineEvent(TraceEventWrapper firstTraceEvent)
      : _parentId = firstTraceEvent.event.args![parentIdKey] as String?,
        super(firstTraceEvent) {
    type = TimelineEventType.async;
  }

  static const parentIdKey = 'parentId';

  String get asyncId => traceEvents.first.event.id!;

  String get asyncUID => traceEvents.first.event.asyncUID;

  bool get hasExplicitParent => _parentId != null;

  /// Unique id for this async event's parent event.
  ///
  /// This field is not guaranteed to be non-null.
  final String? _parentId;

  /// Async UID id for this async event's parent, including information about
  /// the event's category.
  ///
  /// This format matches [TraceEvent.asyncUID].
  String get parentAsyncUID => generateAsyncUID(
        id: _parentId,
        category: traceEvents.first.event.category,
      );

  int? _maxEndMicros;
  @override
  int get maxEndMicros => _maxEndMicros ?? _calculateMaxEndMicros();

  int _calculateMaxEndMicros() {
    if (children.isEmpty) {
      return time.end!.inMicroseconds;
    }
    var maxEnd = time.end!.inMicroseconds;
    for (AsyncTimelineEvent child in children.cast<AsyncTimelineEvent>()) {
      maxEnd = math.max(maxEnd, child._calculateMaxEndMicros());
    }
    return _maxEndMicros = maxEnd;
  }

  @override
  List<List<TimelineEvent>> _calculateDisplayRows() {
    final rows = <List<TimelineEvent>>[];
    _expandDisplayRows(rows: rows, newRowLength: 1);

    const currentRow = 0;
    rows[currentRow].add(this);

    const mainChildRow = currentRow + 1;
    for (int i = 0; i < children.length; i++) {
      final AsyncTimelineEvent child = children[i] as AsyncTimelineEvent;
      if (i == 0 ||
          _eventFitsAtDisplayRow(
            event: child,
            displayRow: mainChildRow,
            currentLargestRowIndex: rows.length,
            rows: rows,
          )) {
        _mergeChildDisplayRows(
          mergeStartLevel: mainChildRow,
          child: child,
          rows: rows,
        );
      } else {
        // If [child] does not fit on the target row, add it below the current
        // deepest display row.
        _mergeChildDisplayRows(
          mergeStartLevel: rows.length,
          child: child,
          rows: rows,
        );
      }
    }
    return rows;
  }

  bool _eventFitsAtDisplayRow({
    required AsyncTimelineEvent event,
    required int displayRow,
    required int currentLargestRowIndex,
    required List<List<TimelineEvent>> rows,
  }) {
    final maxLevelToVerify =
        math.min(event.displayDepth, currentLargestRowIndex - displayRow);
    for (int level = 0; level < maxLevelToVerify; level++) {
      final lastEventAtLevel = rows[displayRow + level].safeLast;
      final firstNewEventAtLevel = event.displayRows[level].safeFirst;
      if (lastEventAtLevel != null && firstNewEventAtLevel != null) {
        // Events overlap one another, so [event] does not fit at [displayRow].
        if (lastEventAtLevel.time.overlaps(firstNewEventAtLevel.time)) {
          return false;
        }

        // [firstNewEventAtLevel] ends before [lastEventAtLevel] begins, so
        // [event] does not fit at [displayRow].
        if (firstNewEventAtLevel.time.end! < lastEventAtLevel.time.start!) {
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
            lastEventAtLevel.time.end! >= lastEventParent.time.end!) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void addChild(TimelineEvent child, {int? index}) {
    assert(index == null);
    child = child as AsyncTimelineEvent;
    // Short circuit if we are using an explicit parentId.
    if (child.hasExplicitParent &&
        child.parentAsyncUID == traceEvents.first.event.asyncUID) {
      _addChild(child);
    } else {
      super.addChild(child);
    }
  }

  @override
  bool couldBeParentOf(TimelineEvent e) {
    final asyncEvent = e as AsyncTimelineEvent;

    // If [asyncEvent] has an explicit parentId, use that as the truth.
    if (asyncEvent.hasExplicitParent) {
      return asyncUID == asyncEvent.parentAsyncUID;
    }

    // Without an explicit parentId, two events must share an asyncId to be
    // part of the same event tree.
    if (asyncUID != asyncEvent.asyncUID) return false;

    // When two events share an asyncId, determine parent / child relationships
    // based on timestamps.
    final startTime = time.start!.inMicroseconds;
    final endTime = time.end?.inMicroseconds;
    final eStartTime = e.time.start!.inMicroseconds;
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

  /// End the async event with [eventWrapper] and return whether or not the
  /// end event was successfully added.
  ///
  /// The return value will be used to stop the recursion early.
  bool endAsyncEvent(TraceEventWrapper eventWrapper) {
    assert(
      hasExplicitParent || asyncUID == eventWrapper.event.asyncUID,
      'asyncUID = $asyncUID, but endEventId = ${eventWrapper.event.asyncUID}',
    );
    if (endTraceEventJson != null) {
      // This event has already ended and [eventWrapper] is a duplicate trace
      // event.
      return false;
    }
    if (name == eventWrapper.event.name) {
      addEndEvent(eventWrapper);
      return true;
    }

    for (AsyncTimelineEvent child in children.cast<AsyncTimelineEvent>()) {
      final added = child.endAsyncEvent(eventWrapper);
      if (added) return true;
    }
    return false;
  }
}
