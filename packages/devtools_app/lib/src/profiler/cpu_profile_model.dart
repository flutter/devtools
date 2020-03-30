// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:collection';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../trace_event.dart';
import '../trees.dart';
import '../utils.dart';

/// Data model for DevTools CPU profile.
class CpuProfileData {
  CpuProfileData._({
    @required this.stackFramesJson,
    @required this.stackTraceEvents,
    @required this.profileMetaData,
  }) {
    _cpuProfileRoot = CpuStackFrame(
      id: 'cpuProfile',
      name: 'all',
      category: 'Dart',
      url: '',
      profileMetaData: profileMetaData,
    );
  }

  static CpuProfileData parse(Map<String, dynamic> json) {
    return CpuProfileData._(
      stackFramesJson: jsonDecode(jsonEncode(json[stackFramesKey] ?? {})),
      stackTraceEvents:
          (json[traceEventsKey] ?? []).cast<Map<String, dynamic>>(),
      profileMetaData: CpuProfileMetaData(
        sampleCount: json[sampleCountKey] ?? 0,
        samplePeriod: json[samplePeriodKey],
        stackDepth: json[stackDepthKey],
        time: (json[timeOriginKey] != null && json[timeExtentKey] != null)
            ? (TimeRange()
              ..start = Duration(microseconds: json[timeOriginKey])
              ..end = Duration(
                  microseconds: json[timeOriginKey] + json[timeExtentKey]))
            : null,
      ),
    );
  }

  static CpuProfileData subProfile(
    CpuProfileData superProfile,
    TimeRange subTimeRange,
  ) {
    // Each trace event in [subTraceEvents] will have the leaf stack frame id
    // for a cpu sample within [subTimeRange].
    final subTraceEvents = superProfile.stackTraceEvents
        .where((trace) => subTimeRange
            .contains(Duration(microseconds: trace[TraceEvent.timestampKey])))
        .toList();

    // Use a SplayTreeMap so that map iteration will be in sorted key order.
    final SplayTreeMap<String, Map<String, dynamic>> subStackFramesJson =
        SplayTreeMap(stackFrameIdCompare);
    for (Map<String, dynamic> traceEvent in subTraceEvents) {
      // Add leaf frame.
      final String leafId = traceEvent[stackFrameIdKey];
      final Map<String, dynamic> leafFrameJson =
          superProfile.stackFramesJson[leafId];
      subStackFramesJson[leafId] = leafFrameJson;

      // Add leaf frame's ancestors.
      String parentId = leafFrameJson[parentIdKey];
      while (parentId != null) {
        final parentFrameJson = superProfile.stackFramesJson[parentId];
        subStackFramesJson[parentId] = parentFrameJson;
        parentId = parentFrameJson[parentIdKey];
      }
    }

    return CpuProfileData._(
      stackFramesJson: subStackFramesJson,
      stackTraceEvents: subTraceEvents,
      profileMetaData: CpuProfileMetaData(
        sampleCount: subTraceEvents.length,
        samplePeriod: superProfile.profileMetaData.samplePeriod,
        stackDepth: superProfile.profileMetaData.stackDepth,
        time: subTimeRange,
      ),
    );
  }

  static CpuProfileData empty() => parse({});

  // Key fields from the VM response JSON.
  static const nameKey = 'name';
  static const categoryKey = 'category';
  static const parentIdKey = 'parent';
  static const stackFrameIdKey = 'sf';
  static const resolvedUrlKey = 'resolvedUrl';
  static const stackFramesKey = 'stackFrames';
  static const traceEventsKey = 'traceEvents';
  static const sampleCountKey = 'sampleCount';
  static const stackDepthKey = 'stackDepth';
  static const samplePeriodKey = 'samplePeriod';
  static const timeOriginKey = 'timeOriginMicros';
  static const timeExtentKey = 'timeExtentMicros';

  /// Marks whether this data has already been processed.
  bool processed = false;

  final Map<String, dynamic> stackFramesJson;

  /// Trace events associated with the last stackFrame in each sample (i.e. the
  /// leaves of the [CpuStackFrame] objects).
  ///
  /// The trace event will contain a field 'sf' that contains the id of the leaf
  /// stack frame.
  final List<Map<String, dynamic>> stackTraceEvents;

  final CpuProfileMetaData profileMetaData;

  CpuStackFrame get cpuProfileRoot => _cpuProfileRoot;

  CpuStackFrame _cpuProfileRoot;

  Map<String, CpuStackFrame> stackFrames = {};

  CpuStackFrame selectedStackFrame;

  Map<String, dynamic> get json => {
        'type': '_CpuProfileTimeline',
        samplePeriodKey: profileMetaData.samplePeriod,
        sampleCountKey: profileMetaData.sampleCount,
        stackDepthKey: profileMetaData.stackDepth,
        timeOriginKey: profileMetaData.time.start.inMicroseconds,
        timeExtentKey: profileMetaData.time.duration.inMicroseconds,
        stackFramesKey: stackFramesJson,
        traceEventsKey: stackTraceEvents,
      };

  bool get isEmpty => profileMetaData.sampleCount == 0;
}

class CpuProfileMetaData {
  CpuProfileMetaData({
    @required this.sampleCount,
    @required this.samplePeriod,
    @required this.stackDepth,
    @required this.time,
  });

  final int sampleCount;

  final int samplePeriod;

  final int stackDepth;

  final TimeRange time;
}

class CpuStackFrame extends TreeNode<CpuStackFrame> {
  CpuStackFrame({
    @required this.id,
    @required this.name,
    @required this.category,
    @required this.url,
    @required this.profileMetaData,
  });

  final String id;

  final String name;

  final String category;

  final String url;

  final CpuProfileMetaData profileMetaData;

  /// How many cpu samples for which this frame is a leaf.
  int exclusiveSampleCount = 0;

  int get inclusiveSampleCount =>
      _inclusiveSampleCount ?? _calculateInclusiveSampleCount();

  /// How many cpu samples this frame is included in.
  int _inclusiveSampleCount;
  set inclusiveSampleCount(int count) => _inclusiveSampleCount = count;

  double get totalTimeRatio => _totalTimeRatio ??=
      safeDivide(inclusiveSampleCount, profileMetaData.sampleCount);

  double _totalTimeRatio;

  Duration get totalTime => _totalTime ??= Duration(
      microseconds:
          (totalTimeRatio * profileMetaData.time.duration.inMicroseconds)
              .round());

  Duration _totalTime;

  double get selfTimeRatio => _selfTimeRatio ??=
      safeDivide(exclusiveSampleCount, profileMetaData.sampleCount);

  double _selfTimeRatio;

  Duration get selfTime => _selfTime ??= Duration(
      microseconds:
          (selfTimeRatio * profileMetaData.time.duration.inMicroseconds)
              .round());

  Duration _selfTime;

  /// Returns the number of cpu samples this stack frame is a part of.
  ///
  /// This will be equal to the number of leaf nodes under this stack frame.
  int _calculateInclusiveSampleCount() {
    int count = exclusiveSampleCount;
    for (CpuStackFrame child in children) {
      count += child.inclusiveSampleCount;
    }
    _inclusiveSampleCount = count;
    return _inclusiveSampleCount;
  }

  CpuStackFrame shallowCopy({bool resetInclusiveSampleCount = false}) {
    final copy = CpuStackFrame(
      id: id,
      name: name,
      category: category,
      url: url,
      profileMetaData: profileMetaData,
    )
      ..exclusiveSampleCount = exclusiveSampleCount
      ..inclusiveSampleCount =
          resetInclusiveSampleCount ? null : inclusiveSampleCount;
    return copy;
  }

  /// Returns a deep copy from this stack frame down to the leaves of the tree.
  ///
  /// The returned copy stack frame will have a null parent.
  CpuStackFrame deepCopy() {
    final copy = shallowCopy();
    for (CpuStackFrame child in children) {
      copy.addChild(child.deepCopy());
    }
    return copy;
  }

  /// Whether [this] stack frame matches another stack frame [other].
  ///
  /// Two stack frames are said to be matching if they share the following
  /// properties.
  bool matches(CpuStackFrame other) =>
      name == other.name && url == other.url && category == other.category;

  void _format(StringBuffer buf, String indent) {
    buf.writeln('$indent$name - children: ${children.length} - excl: '
            '$exclusiveSampleCount - incl: $inclusiveSampleCount'
        .trimRight());
    for (CpuStackFrame child in children) {
      child._format(buf, '  $indent');
    }
  }

  @visibleForTesting
  String toStringDeep() {
    final buf = StringBuffer();
    _format(buf, '  ');
    return buf.toString();
  }

  @override
  String toString() {
    final buf = StringBuffer();
    buf.write('$name ');
    if (totalTime != null) {
      // TODO(kenz): use a number of fractionDigits that better matches the
      // resolution of the stack frame.
      buf.write('- ${msText(totalTime, fractionDigits: 2)} ');
    }
    buf.write('($inclusiveSampleCount ');
    buf.write(inclusiveSampleCount == 1 ? 'sample' : 'samples');
    buf.write(', ${percent2(totalTimeRatio)})');
    return buf.toString();
  }
}

@visibleForTesting
int stackFrameIdCompare(String a, String b) {
  // Stack frame ids are structured as 140225212960768-24 (iOS) or -784070656-24
  // (Android). We need to compare the number after the last dash to maintain
  // the correct order.
  const dash = '-';
  final aDashIndex = a.lastIndexOf(dash);
  final bDashIndex = b.lastIndexOf(dash);
  try {
    final int aId = int.parse(a.substring(aDashIndex + 1));
    final int bId = int.parse(b.substring(bDashIndex + 1));
    return aId.compareTo(bId);
  } catch (e) {
    String error = 'invalid stack frame ';
    if (aDashIndex == -1 && bDashIndex != -1) {
      error += 'id [$a]';
    } else if (aDashIndex != -1 && bDashIndex == -1) {
      error += 'id [$b]';
    } else {
      error += 'ids [$a, $b]';
    }
    throw error;
  }
}
