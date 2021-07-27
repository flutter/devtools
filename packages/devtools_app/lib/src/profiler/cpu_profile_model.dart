// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:collection';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../charts/flame_chart.dart';
import '../trace_event.dart';
import '../trees.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'cpu_profile_transformer.dart';

/// Data model for DevTools CPU profile.
class CpuProfileData {
  CpuProfileData._({
    @required this.stackFrames,
    @required this.cpuSamples,
    @required this.profileMetaData,
  }) {
    _cpuProfileRoot = CpuStackFrame(
      id: rootId,
      name: rootName,
      verboseName: rootName,
      category: 'Dart',
      url: '',
      profileMetaData: profileMetaData,
      parentId: null,
    );
  }

  factory CpuProfileData.parse(Map<String, dynamic> json) {
    final profileMetaData = CpuProfileMetaData(
      sampleCount: json[sampleCountKey] ?? 0,
      samplePeriod: json[samplePeriodKey],
      stackDepth: json[stackDepthKey],
      time: (json[timeOriginKey] != null && json[timeExtentKey] != null)
          ? (TimeRange()
            ..start = Duration(microseconds: json[timeOriginKey])
            ..end = Duration(
                microseconds: json[timeOriginKey] + json[timeExtentKey]))
          : null,
    );

    // Initialize all stack frames.
    final stackFrames = <String, CpuStackFrame>{};
    final stackFramesJson =
        jsonDecode(jsonEncode(json[stackFramesKey] ?? <String, dynamic>{}));
    for (final MapEntry<String, dynamic> entry in stackFramesJson.entries) {
      final stackFrameJson = entry.value;
      final stackFrame = CpuStackFrame(
        id: entry.key,
        name: getSimpleStackFrameName(stackFrameJson[nameKey]),
        verboseName: stackFrameJson[nameKey],
        category: stackFrameJson[categoryKey],
        // If the user is on a version of Flutter where resolvedUrl is not
        // included in the response, this will be null. If the frame is a native
        // frame, the this will be the empty string.
        url: stackFrameJson[resolvedUrlKey] ?? '',
        parentId: stackFrameJson[parentIdKey],
        profileMetaData: profileMetaData,
      );
      stackFrames[stackFrame.id] = stackFrame;
    }

    // Initialize all CPU samples.
    final stackTraceEvents =
        (json[traceEventsKey] ?? []).cast<Map<String, dynamic>>();
    final samples = stackTraceEvents
        .map((trace) => CpuSample.parse(trace))
        .toList()
        .cast<CpuSample>();

    return CpuProfileData._(
      stackFrames: stackFrames,
      cpuSamples: samples,
      profileMetaData: profileMetaData,
    );
  }

  factory CpuProfileData.subProfile(
    CpuProfileData superProfile,
    TimeRange subTimeRange,
  ) {
    // Each sample in [subSamples] will have the leaf stack
    // frame id for a cpu sample within [subTimeRange].
    final subSamples = superProfile.cpuSamples
        .where((sample) => subTimeRange
            .contains(Duration(microseconds: sample.timestampMicros)))
        .toList();

    // Use a SplayTreeMap so that map iteration will be in sorted key order.
    final SplayTreeMap<String, CpuStackFrame> subStackFrames =
        SplayTreeMap(stackFrameIdCompare);
    for (final sample in subSamples) {
      final leafFrame = superProfile.stackFrames[sample.leafId];
      subStackFrames[sample.leafId] = leafFrame;

      // Add leaf frame's ancestors.
      String parentId = leafFrame.parentId;
      while (parentId != null) {
        final parentFrame = superProfile.stackFrames[parentId];
        subStackFrames[parentId] = parentFrame;
        parentId = parentFrame.parentId;
      }
    }

    return CpuProfileData._(
      stackFrames: subStackFrames,
      cpuSamples: subSamples,
      profileMetaData: CpuProfileMetaData(
        sampleCount: subSamples.length,
        samplePeriod: superProfile.profileMetaData.samplePeriod,
        stackDepth: superProfile.profileMetaData.stackDepth,
        time: subTimeRange,
      ),
    );
  }

  factory CpuProfileData.fromUserTag(CpuProfileData originalData, String tag) {
    if (!originalData.userTags.contains(tag)) {
      return CpuProfileData.empty();
    }

    final samplesForTag = originalData.cpuSamples
        .where((sample) => sample.userTag == tag)
        .toList();
    assert(samplesForTag.isNotEmpty);

    // Use a SplayTreeMap so that map iteration will be in sorted key order.
    final SplayTreeMap<String, CpuStackFrame> stackFramesForTag =
        SplayTreeMap(stackFrameIdCompare);

    for (final sample in samplesForTag) {
      var currentId = sample.leafId;
      var currentStackFrame = originalData.stackFrames[currentId];

      while (currentStackFrame != null) {
        stackFramesForTag[currentId] = currentStackFrame.shallowCopy(
          copySampleCountsAndTags: false,
        );
        final parentId = currentStackFrame.parentId;
        final parentStackFrameJson =
            parentId != null ? originalData.stackFrames[parentId] : null;
        currentId = parentId;
        currentStackFrame = parentStackFrameJson;
      }
    }

    final originalTime = originalData.profileMetaData.time.duration;
    final microsPerSample =
        originalTime.inMicroseconds / originalData.profileMetaData.sampleCount;
    final newSampleCount = samplesForTag.length;
    final metaData = originalData.profileMetaData.copyWith(
      sampleCount: newSampleCount,
      // The start time is zero because only `TimeRange.duration` will matter
      // for this profile data, and the samples included in this data could be
      // sparse over the original profile's time range, so true start and end
      // times wouldn't be helpful.
      time: TimeRange()
        ..start = const Duration()
        ..end =
            Duration(microseconds: (newSampleCount * microsPerSample).round()),
    );

    return CpuProfileData._(
      stackFrames: stackFramesForTag,
      cpuSamples: samplesForTag,
      profileMetaData: metaData,
    );
  }

  factory CpuProfileData.empty() => CpuProfileData.parse({});

  static const rootId = 'cpuProfileRoot';

  static const rootName = 'all';

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
  static const userTagKey = 'userTag';

  final Map<String, CpuStackFrame> stackFrames;

  final List<CpuSample> cpuSamples;

  final CpuProfileMetaData profileMetaData;

  /// Marks whether this data has already been processed.
  bool processed = false;

  List<CpuStackFrame> get callTreeRoots {
    if (!processed) return <CpuStackFrame>[];
    return _callTreeRoots ??= [_cpuProfileRoot.deepCopy()];
  }

  List<CpuStackFrame> _callTreeRoots;

  List<CpuStackFrame> get bottomUpRoots {
    if (!processed) return <CpuStackFrame>[];
    return _bottomUpRoots ??=
        BottomUpProfileTransformer.processData(_cpuProfileRoot);
  }

  List<CpuStackFrame> _bottomUpRoots;

  CpuStackFrame get cpuProfileRoot => _cpuProfileRoot;

  Iterable<String> get userTags => _cpuProfileRoot.userTags;

  CpuStackFrame _cpuProfileRoot;

  CpuStackFrame selectedStackFrame;

  Map<String, Object> get toJson => {
        'type': '_CpuProfileTimeline',
        samplePeriodKey: profileMetaData.samplePeriod,
        sampleCountKey: profileMetaData.sampleCount,
        stackDepthKey: profileMetaData.stackDepth,
        if (profileMetaData?.time?.start != null)
          timeOriginKey: profileMetaData.time.start.inMicroseconds,
        if (profileMetaData?.time?.duration != null)
          timeExtentKey: profileMetaData.time.duration.inMicroseconds,
        stackFramesKey: stackFramesJson,
        traceEventsKey: cpuSamples.map((sample) => sample.json).toList(),
      };

  bool get isEmpty => profileMetaData.sampleCount == 0;

  @visibleForTesting
  Map<String, dynamic> get stackFramesJson {
    final framesJson = <String, dynamic>{};
    for (final sf in stackFrames.values) {
      framesJson.addAll(sf.toJson);
    }
    return framesJson;
  }
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

  CpuProfileMetaData copyWith({
    int sampleCount,
    int samplePeriod,
    int stackDepth,
    TimeRange time,
  }) {
    return CpuProfileMetaData(
      sampleCount: sampleCount ?? this.sampleCount,
      samplePeriod: samplePeriod ?? this.samplePeriod,
      stackDepth: stackDepth ?? this.stackDepth,
      time: time ?? this.time,
    );
  }
}

class CpuSample extends TraceEvent {
  CpuSample({
    @required this.leafId,
    this.userTag,
    Map<String, dynamic> traceJson,
  }) : super(traceJson);

  factory CpuSample.parse(Map<String, dynamic> traceJson) {
    final leafId = traceJson[CpuProfileData.stackFrameIdKey];
    final userTag = traceJson[TraceEvent.argsKey] != null
        ? traceJson[TraceEvent.argsKey][CpuProfileData.userTagKey]
        : null;
    return CpuSample(leafId: leafId, userTag: userTag, traceJson: traceJson);
  }

  final String leafId;

  final String userTag;
}

class CpuStackFrame extends TreeNode<CpuStackFrame>
    with
        DataSearchStateMixin,
        TreeDataSearchStateMixin<CpuStackFrame>,
        FlameChartDataMixin {
  CpuStackFrame({
    @required this.id,
    @required this.name,
    @required this.verboseName,
    @required this.category,
    @required this.url,
    @required this.parentId,
    @required this.profileMetaData,
  });

  final String id;

  final String name;

  final String verboseName;

  final String category;

  final String url;

  final String parentId;

  final CpuProfileMetaData profileMetaData;

  Iterable<String> get userTags => _userTagSampleCount.keys;

  /// Maps a user tag to the number of CPU samples associated with it.
  ///
  /// A single [CpuStackFrame] can have multiple tags because a single object
  /// can be part of multiple samples.
  final _userTagSampleCount = <String, int>{};

  void incrementTagSampleCount(String userTag, {int increment = 1}) {
    assert(userTag != null);
    final currentCount = _userTagSampleCount.putIfAbsent(userTag, () => 0);
    _userTagSampleCount[userTag] = currentCount + increment;

    if (parent != null) {
      parent.incrementTagSampleCount(userTag);
    }
  }

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

  @override
  String get tooltip => [
        name,
        msText(totalTime),
        if (url != null) url,
      ].join(' - ');

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

  @override
  CpuStackFrame shallowCopy({
    String id,
    String name,
    String verboseName,
    String category,
    String url,
    String parentId,
    CpuProfileMetaData profileMetaData,
    bool copySampleCountsAndTags = true,
    bool resetInclusiveSampleCount = true,
  }) {
    final copy = CpuStackFrame(
      id: id ?? this.id,
      name: name ?? this.name,
      verboseName: verboseName ?? this.verboseName,
      category: category ?? this.category,
      url: url ?? this.url,
      parentId: parentId ?? this.parentId,
      profileMetaData: profileMetaData ?? this.profileMetaData,
    );
    if (copySampleCountsAndTags) {
      copy
        ..exclusiveSampleCount = exclusiveSampleCount
        ..inclusiveSampleCount =
            resetInclusiveSampleCount ? null : inclusiveSampleCount;
      for (final entry in _userTagSampleCount.entries) {
        copy.incrementTagSampleCount(entry.key, increment: entry.value);
      }
    }
    return copy;
  }

  /// Returns a deep copy from this stack frame down to the leaves of the tree.
  ///
  /// The returned copy stack frame will have a null parent.
  CpuStackFrame deepCopy() {
    final copy = shallowCopy(resetInclusiveSampleCount: false);
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

  Map<String, Object> get toJson => {
        id: {
          CpuProfileData.nameKey: verboseName,
          CpuProfileData.categoryKey: category,
          CpuProfileData.resolvedUrlKey: url,
          if (parentId != null) CpuProfileData.parentIdKey: parentId,
        }
      };

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

class CpuProfileStore {
  final _profiles = <TimeRange, CpuProfileData>{};

  /// Lookup a profile from the cache [_profiles] for the given range [time].
  ///
  /// If [_profiles] contains a CPU profile for a time range that encompasses
  /// [time], a sub profile will be generated, cached in [_profiles] and then
  /// returned. This method will return null if no profiles are cached for
  /// [time] or if a sub profile cannot be generated for [time].
  CpuProfileData lookupProfile(TimeRange time) {
    if (!time.isWellFormed) return null;

    // If we have a profile for a time range encompassing [time], then we can
    // generate and cache the profile for [time] without needing to pull data
    // from the vm service.
    _maybeGenerateSubProfile(time);
    return _profiles[time];
  }

  void addProfile(TimeRange time, CpuProfileData profile) {
    _profiles[time] = profile;
  }

  void _maybeGenerateSubProfile(TimeRange time) {
    if (_profiles.containsKey(time)) return;
    final encompassingTimeRange = _encompassingTimeRange(time);
    if (encompassingTimeRange != null) {
      final encompassingProfile = _profiles[encompassingTimeRange];

      final subProfile = CpuProfileData.subProfile(encompassingProfile, time);
      _profiles[time] = subProfile;
    }
  }

  TimeRange _encompassingTimeRange(TimeRange time) {
    int shortestDurationMicros = maxJsInt;
    TimeRange encompassingTimeRange;
    for (final t in _profiles.keys) {
      // We want to find the shortest encompassing time range for [time].
      if (t.containsRange(time) &&
          t.duration.inMicroseconds < shortestDurationMicros) {
        shortestDurationMicros = t.duration.inMicroseconds;
        encompassingTimeRange = t;
      }
    }
    return encompassingTimeRange;
  }

  void clear() {
    _profiles.clear();
  }
}
