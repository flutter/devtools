// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../../charts/flame_chart.dart';
import '../../primitives/simple_items.dart';
import '../../primitives/trace_event.dart';
import '../../primitives/trees.dart';
import '../../primitives/utils.dart';
import '../../shared/globals.dart';
import '../../shared/profiler_utils.dart';
import '../../ui/search.dart';
import 'cpu_profile_transformer.dart';

/// Data model for DevTools CPU profile.
class CpuProfileData {
  CpuProfileData._({
    required this.stackFrames,
    required this.cpuSamples,
    required this.profileMetaData,
  }) {
    _cpuProfileRoot = CpuStackFrame._(
      id: rootId,
      name: rootName,
      verboseName: rootName,
      category: 'Dart',
      rawUrl: '',
      packageUri: '',
      sourceLine: null,
      profileMetaData: profileMetaData,
      parentId: null,
    );
  }

  factory CpuProfileData.parse(Map<String, dynamic> json) {
    final profileMetaData = CpuProfileMetaData(
      sampleCount: json[sampleCountKey] ?? 0,
      samplePeriod: json[samplePeriodKey] ?? 0,
      stackDepth: json[stackDepthKey] ?? 0,
      time: (json[timeOriginKey] != null && json[timeExtentKey] != null)
          ? (TimeRange()
            ..start = Duration(microseconds: json[timeOriginKey])
            ..end = Duration(
              microseconds: json[timeOriginKey] + json[timeExtentKey],
            ))
          : null,
    );

    // Initialize all stack frames.
    final stackFrames = <String, CpuStackFrame>{};
    final Map<String, dynamic> stackFramesJson =
        jsonDecode(jsonEncode(json[stackFramesKey] ?? <String, dynamic>{}));
    for (final MapEntry<String, dynamic> entry in stackFramesJson.entries) {
      final stackFrameJson = entry.value;
      final resolvedUrl = stackFrameJson[resolvedUrlKey] ?? '';
      final packageUri = stackFrameJson[resolvedPackageUriKey] ?? resolvedUrl;
      final stackFrame = CpuStackFrame(
        id: entry.key,
        name: getSimpleStackFrameName(stackFrameJson[nameKey]),
        verboseName: stackFrameJson[nameKey],
        category: stackFrameJson[categoryKey],
        // If the user is on a version of Flutter where resolvedUrl is not
        // included in the response, this will be null. If the frame is a native
        // frame, the this will be the empty string.
        rawUrl: resolvedUrl,
        packageUri: packageUri,
        sourceLine: stackFrameJson[sourceLineKey],
        parentId: stackFrameJson[parentIdKey] ?? rootId,
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
        .where(
          (sample) => subTimeRange
              .contains(Duration(microseconds: sample.timestampMicros!)),
        )
        .toList();

    // Use a SplayTreeMap so that map iteration will be in sorted key order.
    // This keeps the visualization of the profile as consistent as possible
    // when applying filters.
    final SplayTreeMap<String, CpuStackFrame> subStackFrames =
        SplayTreeMap(stackFrameIdCompare);
    for (final sample in subSamples) {
      final leafFrame = superProfile.stackFrames[sample.leafId]!;
      subStackFrames[sample.leafId] = leafFrame;

      // Add leaf frame's ancestors.
      String? parentId = leafFrame.parentId;
      while (parentId != null && parentId != rootId) {
        final parentFrame = superProfile.stackFrames[parentId]!;
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

  /// Generate a cpu profile from [originalData] where each sample contains the
  /// userTag [tag].
  ///
  /// [originalData] does not need to be [processed] to run this operation.
  factory CpuProfileData.fromUserTag(CpuProfileData originalData, String tag) {
    if (!originalData.userTags.contains(tag)) {
      return CpuProfileData.empty();
    }

    final samplesWithTag = originalData.cpuSamples
        .where((sample) => sample.userTag == tag)
        .toList();
    assert(samplesWithTag.isNotEmpty);

    final originalTime = originalData.profileMetaData.time!.duration;
    final microsPerSample =
        originalTime.inMicroseconds / originalData.profileMetaData.sampleCount;
    final newSampleCount = samplesWithTag.length;
    final metaData = originalData.profileMetaData.copyWith(
      sampleCount: newSampleCount,
      // The start time is zero because only `TimeRange.duration` will matter
      // for this profile data, and the samples included in this data could be
      // sparse over the original profile's time range, so true start and end
      // times wouldn't be helpful.
      time: TimeRange()
        ..start = const Duration()
        ..end = Duration(
          microseconds: microsPerSample.isInfinite
              ? 0
              : (newSampleCount * microsPerSample).round(),
        ),
    );

    // Use a SplayTreeMap so that map iteration will be in sorted key order.
    // This keeps the visualization of the profile as consistent as possible
    // when applying filters.
    final SplayTreeMap<String, CpuStackFrame> stackFramesWithTag =
        SplayTreeMap(stackFrameIdCompare);

    for (final sample in samplesWithTag) {
      String? currentId = sample.leafId;
      var currentStackFrame = originalData.stackFrames[currentId];

      while (currentStackFrame != null) {
        stackFramesWithTag[currentId!] = currentStackFrame.shallowCopy(
          copySampleCounts: false,
          profileMetaData: metaData,
        );
        final parentId = currentStackFrame.parentId;
        final parentStackFrameJson =
            parentId != null ? originalData.stackFrames[parentId] : null;
        currentId = parentId;
        currentStackFrame = parentStackFrameJson;
      }
    }

    return CpuProfileData._(
      stackFrames: stackFramesWithTag,
      cpuSamples: samplesWithTag,
      profileMetaData: metaData,
    );
  }

  /// Generate a cpu profile from [originalData] where each stack frame meets
  /// the condition specified by [includeFilter].
  ///
  /// [originalData] does not need to be [processed] to run this operation.
  factory CpuProfileData.filterFrom(
    CpuProfileData originalData,
    bool Function(CpuStackFrame) includeFilter,
  ) {
    final filteredCpuSamples = <CpuSample>[];
    void includeSampleOrWalkUp(
      CpuSample sample,
      Map<String, Object> sampleJson,
      CpuStackFrame stackFrame,
    ) {
      if (includeFilter(stackFrame)) {
        filteredCpuSamples.add(
          CpuSample(
            leafId: stackFrame.id,
            userTag: sample.userTag,
            traceJson: sampleJson,
          ),
        );
      } else if (stackFrame.parentId != CpuProfileData.rootId) {
        final parent = originalData.stackFrames[stackFrame.parentId]!;
        includeSampleOrWalkUp(sample, sampleJson, parent);
      }
    }

    for (final sample in originalData.cpuSamples) {
      final sampleJson = Map<String, Object>.from(sample.json);
      final leafStackFrame = originalData.stackFrames[sample.leafId]!;
      includeSampleOrWalkUp(sample, sampleJson, leafStackFrame);
    }

    // Use a SplayTreeMap so that map iteration will be in sorted key order.
    // This keeps the visualization of the profile as consistent as possible
    // when applying filters.
    final SplayTreeMap<String, CpuStackFrame> filteredStackFrames =
        SplayTreeMap(stackFrameIdCompare);

    String? filteredParentStackFrameId(CpuStackFrame? candidateParentFrame) {
      if (candidateParentFrame == null) return null;

      if (includeFilter(candidateParentFrame)) {
        return candidateParentFrame.id;
      } else if (candidateParentFrame.parentId != CpuProfileData.rootId) {
        final parent = originalData.stackFrames[candidateParentFrame.parentId]!;
        return filteredParentStackFrameId(parent);
      }
      return null;
    }

    final originalTime = originalData.profileMetaData.time!.duration;
    final microsPerSample =
        originalTime.inMicroseconds / originalData.profileMetaData.sampleCount;
    final updatedMetaData = originalData.profileMetaData.copyWith(
      sampleCount: filteredCpuSamples.length,
      // The start time is zero because only `TimeRange.duration` will matter
      // for this profile data, and the samples included in this data could be
      // sparse over the original profile's time range, so true start and end
      // times wouldn't be helpful.
      time: TimeRange()
        ..start = const Duration()
        ..end = Duration(
          microseconds: microsPerSample.isInfinite || microsPerSample.isNaN
              ? 0
              : (filteredCpuSamples.length * microsPerSample).round(),
        ),
    );

    void walkAndFilter(CpuStackFrame stackFrame) {
      if (includeFilter(stackFrame)) {
        final parent = originalData.stackFrames[stackFrame.parentId];
        final filteredParentId = filteredParentStackFrameId(parent);
        filteredStackFrames[stackFrame.id] = stackFrame.shallowCopy(
          parentId: filteredParentId,
          copySampleCounts: false,
          profileMetaData: updatedMetaData,
        );
        if (filteredParentId != null) {
          walkAndFilter(originalData.stackFrames[filteredParentId]!);
        }
      } else if (stackFrame.parentId != CpuProfileData.rootId) {
        final parent = originalData.stackFrames[stackFrame.parentId]!;
        walkAndFilter(parent);
      }
    }

    for (final sample in filteredCpuSamples) {
      final leafStackFrame = originalData.stackFrames[sample.leafId]!;
      walkAndFilter(leafStackFrame);
    }

    return CpuProfileData._(
      stackFrames: filteredStackFrames,
      cpuSamples: filteredCpuSamples,
      profileMetaData: updatedMetaData,
    );
  }

  factory CpuProfileData.empty() => CpuProfileData.parse({});

  /// Generates [CpuProfileData] from the provided [CpuSamples].
  ///
  /// [isolateId] The isolate id which was used to get the [cpuSamples].
  /// This will be used to tag the stack frames and trace events.
  /// [cpuSamples] The CPU samples that will be used to generate the [CpuProfileData]
  static Future<CpuProfileData> generateFromCpuSamples({
    required String isolateId,
    required vm_service.CpuSamples cpuSamples,
  }) async {
    // The root ID is associated with an artificial frame / node that is the root
    // of all stacks, regardless of entrypoint. This should never be seen in the
    // final output from this method.
    const int kRootId = 0;
    int nextId = kRootId;
    final traceObject = <String, dynamic>{
      CpuProfileData.sampleCountKey: cpuSamples.sampleCount,
      CpuProfileData.samplePeriodKey: cpuSamples.samplePeriod,
      CpuProfileData.stackDepthKey: cpuSamples.maxStackDepth,
      CpuProfileData.timeOriginKey: cpuSamples.timeOriginMicros,
      CpuProfileData.timeExtentKey: cpuSamples.timeExtentMicros,
      CpuProfileData.stackFramesKey: {},
      CpuProfileData.traceEventsKey: [],
    };

    String? nameForStackFrame(_CpuProfileTimelineTree current) {
      final className = current.className;
      if (className != null) {
        return '$className.${current.name}';
      }
      return current.name;
    }

    void processStackFrame({
      required _CpuProfileTimelineTree current,
      required _CpuProfileTimelineTree? parent,
    }) {
      final id = nextId++;
      current.frameId = id;

      // Skip the root.
      if (id != kRootId) {
        final key = '$isolateId-$id';
        traceObject[CpuProfileData.stackFramesKey][key] = {
          CpuProfileData.categoryKey: 'Dart',
          CpuProfileData.nameKey: nameForStackFrame(current),
          CpuProfileData.resolvedUrlKey: current.resolvedUrl,
          CpuProfileData.sourceLineKey: current.sourceLine,
          if (parent != null && parent.frameId != 0)
            CpuProfileData.parentIdKey: '$isolateId-${parent.frameId}',
        };
      }
      for (final child in current.children) {
        processStackFrame(current: child, parent: current);
      }
    }

    final root = _CpuProfileTimelineTree.fromCpuSamples(cpuSamples);
    processStackFrame(current: root, parent: null);

    // Build the trace events.
    for (final sample in cpuSamples.samples ?? <vm_service.CpuSample>[]) {
      final tree = _CpuProfileTimelineTree.getTreeFromSample(sample)!;
      // Skip the root.
      if (tree.frameId == kRootId) {
        continue;
      }
      traceObject[CpuProfileData.traceEventsKey].add({
        'ph': 'P', // kind = sample event
        'name': '', // Blank to keep about:tracing happy
        'pid': cpuSamples.pid,
        'tid': sample.tid,
        'ts': sample.timestamp,
        'cat': 'Dart',
        CpuProfileData.stackFrameIdKey: '$isolateId-${tree.frameId}',
        'args': {
          if (sample.userTag != null) 'userTag': sample.userTag,
          if (sample.vmTag != null) 'vmTag': sample.vmTag,
        },
      });
    }

    await _addPackageUrisToTraceObject(isolateId, traceObject);

    return CpuProfileData.parse(traceObject);
  }

  /// Helper function for determining and updating the
  /// [CpuProfileData.resolvedPackageUriKey] entry for each stack frame in
  /// [traceObject].
  ///
  /// [isolateId] The id which is passed to the getIsolate RPC to load this
  /// isolate.
  /// [traceObject] A map where the cpu profile data for each frame is stored.
  static Future<void> _addPackageUrisToTraceObject(
    String isolateId,
    Map<String, dynamic> traceObject,
  ) async {
    final stackFrames = traceObject[CpuProfileData.stackFramesKey]
        .values
        .cast<Map<String, dynamic>>();
    final stackFramesWaitingOnPackageUri = <Map<String, dynamic>>[];
    final urisWithoutPackageUri = <String>{};
    for (final stackFrameJson in stackFrames) {
      final resolvedUrl =
          stackFrameJson[CpuProfileData.resolvedUrlKey] as String?;
      if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
        final packageUri = serviceManager.resolvedUriManager
            .lookupPackageUri(isolateId, resolvedUrl);
        if (packageUri != null) {
          stackFrameJson[CpuProfileData.resolvedPackageUriKey] = packageUri;
        } else {
          stackFramesWaitingOnPackageUri.add(stackFrameJson);
          urisWithoutPackageUri.add(resolvedUrl);
        }
      }
    }

    await serviceManager.resolvedUriManager.fetchPackageUris(
      isolateId,
      urisWithoutPackageUri.toList(),
    );

    for (var stackFrameJson in stackFramesWaitingOnPackageUri) {
      final resolvedUri = stackFrameJson[CpuProfileData.resolvedUrlKey];
      final packageUri = serviceManager.resolvedUriManager
          .lookupPackageUri(isolateId, resolvedUri);
      if (packageUri != null) {
        stackFrameJson[CpuProfileData.resolvedPackageUriKey] = packageUri;
      }
    }
  }

  static const rootId = 'cpuProfileRoot';

  static const rootName = 'all';

  // Key fields from the VM response JSON.
  static const nameKey = 'name';
  static const categoryKey = 'category';
  static const parentIdKey = 'parent';
  static const stackFrameIdKey = 'sf';
  static const resolvedUrlKey = 'resolvedUrl';
  static const resolvedPackageUriKey = 'packageUri';
  static const sourceLineKey = 'sourceLine';
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

  List<CpuStackFrame>? _callTreeRoots;

  List<CpuStackFrame> get bottomUpRoots {
    if (!processed) return <CpuStackFrame>[];
    return _bottomUpRoots ??=
        BottomUpTransformer<CpuStackFrame>().bottomUpRootsFor(
      topDownRoot: _cpuProfileRoot,
      mergeSamples: mergeCpuProfileRoots,
    );
  }

  List<CpuStackFrame>? _bottomUpRoots;

  CpuStackFrame get cpuProfileRoot => _cpuProfileRoot;

  Iterable<String> get userTags {
    if (_userTags != null) {
      return _userTags!;
    }
    final tags = <String>{};
    for (final cpuSample in cpuSamples) {
      final tag = cpuSample.userTag;
      if (tag != null) {
        tags.add(tag);
      }
    }
    _userTags = tags;
    return _userTags!;
  }

  Iterable<String>? _userTags;

  late final CpuStackFrame _cpuProfileRoot;

  CpuStackFrame? selectedStackFrame;

  Map<String, Object?> get toJson => {
        'type': '_CpuProfileTimeline',
        samplePeriodKey: profileMetaData.samplePeriod,
        sampleCountKey: profileMetaData.sampleCount,
        stackDepthKey: profileMetaData.stackDepth,
        if (profileMetaData.time?.start != null)
          timeOriginKey: profileMetaData.time!.start!.inMicroseconds,
        if (profileMetaData.time?.duration != null)
          timeExtentKey: profileMetaData.time!.duration.inMicroseconds,
        stackFramesKey: stackFramesJson,
        traceEventsKey: cpuSamples.map((sample) => sample.toJson).toList(),
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

class CpuProfileMetaData extends ProfileMetaData {
  CpuProfileMetaData({
    required int sampleCount,
    required this.samplePeriod,
    required this.stackDepth,
    required TimeRange? time,
  }) : super(sampleCount: sampleCount, time: time);

  final int samplePeriod;

  final int stackDepth;

  CpuProfileMetaData copyWith({
    int? sampleCount,
    int? samplePeriod,
    int? stackDepth,
    TimeRange? time,
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
    required this.leafId,
    this.userTag,
    required Map<String, dynamic> traceJson,
  }) : super(traceJson);

  factory CpuSample.parse(Map<String, dynamic> traceJson) {
    final leafId = traceJson[CpuProfileData.stackFrameIdKey];
    final userTag = traceJson[TraceEvent.argsKey] != null
        ? traceJson[TraceEvent.argsKey][CpuProfileData.userTagKey]
        : null;
    return CpuSample(
      leafId: leafId,
      userTag: userTag,
      traceJson: traceJson,
    );
  }

  final String leafId;

  final String? userTag;

  Map<String, dynamic> get toJson {
    // [leafId] is the source of truth for the leaf id of this sample.
    super.json[CpuProfileData.stackFrameIdKey] = leafId;
    return super.json;
  }
}

class CpuStackFrame extends TreeNode<CpuStackFrame>
    with
        ProfilableDataMixin<CpuStackFrame>,
        DataSearchStateMixin,
        TreeDataSearchStateMixin<CpuStackFrame>,
        FlameChartDataMixin {
  factory CpuStackFrame({
    required String id,
    required String name,
    required String? verboseName,
    required String? category,
    required String rawUrl,
    required String packageUri,
    required int? sourceLine,
    required String parentId,
    required CpuProfileMetaData profileMetaData,
  }) {
    return CpuStackFrame._(
      id: id,
      name: name,
      verboseName: verboseName,
      category: category,
      rawUrl: rawUrl,
      packageUri: packageUri,
      sourceLine: sourceLine,
      parentId: parentId,
      profileMetaData: profileMetaData,
    );
  }

  CpuStackFrame._({
    required this.id,
    required this.name,
    required this.verboseName,
    required this.category,
    required this.rawUrl,
    required this.packageUri,
    required this.sourceLine,
    required this.parentId,
    required CpuProfileMetaData profileMetaData,
  }) : _profileMetaData = profileMetaData;

  final String id;

  final String name;

  final String? verboseName;

  final String? category;

  final String rawUrl;

  final String packageUri;

  String get packageUriWithSourceLine =>
      '$packageUri${sourceLine != null ? ':$sourceLine' : ''}';

  final int? sourceLine;

  final String? parentId;

  @override
  CpuProfileMetaData get profileMetaData => _profileMetaData;

  final CpuProfileMetaData _profileMetaData;

  @override
  String get displayName => name;

  bool get isNative => _isNative ??= id != CpuProfileData.rootId &&
      packageUri.isEmpty &&
      !name.startsWith(PackagePrefixes.flutterEngine);

  bool? _isNative;

  bool get isDartCore =>
      _isDartCore ??= packageUri.startsWith(PackagePrefixes.dart) &&
          !packageUri.startsWith(PackagePrefixes.dartUi);

  bool? _isDartCore;

  bool get isFlutterCore => _isFlutterCore ??=
      packageUri.startsWith(PackagePrefixes.flutterPackage) ||
          name.startsWith(PackagePrefixes.flutterEngine) ||
          packageUri.startsWith(PackagePrefixes.dartUi);

  bool? _isFlutterCore;

  @override
  String get tooltip {
    var prefix = '';
    if (isNative) {
      prefix = '[Native]';
    } else if (isDartCore) {
      prefix = '[Dart]';
    } else if (isFlutterCore) {
      prefix = '[Flutter]';
    }
    final nameWithPrefix = [prefix, name].join(' ');
    return [
      nameWithPrefix,
      msText(totalTime),
      if (packageUriWithSourceLine.isNotEmpty) packageUriWithSourceLine,
    ].join(' - ');
  }

  /// [copySampleCounts] control whether or not the resulting [CpuStackFrame]
  /// will have [exclusiveSampleCount] and [inclusiveSampleCount] initialized.
  ///
  /// Sample counts should only be reset when building a filtered view of the
  /// full set of samples, as some stacks may no longer be included in the
  /// profile, changing the exclusive counts.
  ///
  /// When [copySampleCounts] is true, inclusive sample counts are also reset
  /// by default, unless [resetInclusiveSampleCount] is also set to false.
  /// Inclusive sample counts should only be copied as part of a deep copy of
  /// a tree.
  @override
  CpuStackFrame shallowCopy({
    String? id,
    String? name,
    String? verboseName,
    String? category,
    String? url,
    String? packageUri,
    String? parentId,
    int? sourceLine,
    CpuProfileMetaData? profileMetaData,
    bool copySampleCounts = true,
    bool resetInclusiveSampleCount = true,
  }) {
    final copy = CpuStackFrame._(
      id: id ?? this.id,
      name: name ?? this.name,
      verboseName: verboseName ?? this.verboseName,
      category: category ?? this.category,
      rawUrl: url ?? rawUrl,
      packageUri: packageUri ?? this.packageUri,
      sourceLine: sourceLine ?? this.sourceLine,
      parentId: parentId ?? this.parentId,
      profileMetaData: profileMetaData ?? this.profileMetaData,
    );
    if (copySampleCounts) {
      copy
        ..exclusiveSampleCount = exclusiveSampleCount
        ..inclusiveSampleCount =
            resetInclusiveSampleCount ? null : inclusiveSampleCount;
    }
    return copy;
  }

  /// Returns a deep copy from this stack frame down to the leaves of the tree.
  ///
  /// The returned copy stack frame will have a null parent.
  @override
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
      name == other.name &&
      rawUrl == other.rawUrl &&
      category == other.category &&
      sourceLine == other.sourceLine;

  Map<String, Object> get toJson => {
        id: {
          CpuProfileData.nameKey: verboseName,
          CpuProfileData.categoryKey: category,
          CpuProfileData.resolvedUrlKey: rawUrl,
          CpuProfileData.resolvedPackageUriKey: packageUri,
          CpuProfileData.sourceLineKey: sourceLine,
          if (parentId != null) CpuProfileData.parentIdKey: parentId,
        }
      };

  @override
  String toString() {
    final buf = StringBuffer();
    buf.write('$name ');
    // TODO(kenz): use a number of fractionDigits that better matches the
    // resolution of the stack frame.
    buf.write('- ${msText(totalTime, fractionDigits: 2)} ');
    buf.write('($inclusiveSampleCount ');
    buf.write(inclusiveSampleCount == 1 ? 'sample' : 'samples');
    buf.write(', ${percent2(totalTimeRatio)})');
    return buf.toString();
  }
}

@visibleForTesting
int stackFrameIdCompare(String a, String b) {
  if (a == b) {
    return 0;
  }
  // Order the root first.
  if (a == CpuProfileData.rootId) {
    return -1;
  }
  if (b == CpuProfileData.rootId) {
    return 1;
  }

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

// TODO(kenz): this store could be improved by allowing profiles stored by
// time range to also have a concept of which filters were applied. This isn't
// critical as the CPU profiles that are stored by time will be small, so the
// time that would be saved by only filtering these profiles once is minimal.
class CpuProfileStore {
  /// Store of CPU profiles keyed by a label.
  ///
  /// This label will contain information regarding any toggle filters or user
  /// tag filters applied to the profile.
  final _profilesByLabel = <String, CpuProfileData>{};

  /// Store of CPU profiles keyed by a time range.
  ///
  /// These time ranges are allowed to overlap.
  final _profilesByTime = <TimeRange, CpuProfileData>{};

  /// Lookup a profile from either cache: [_profilesByLabel] or
  /// [_profilesByTime].
  ///
  /// Only one of [label] and [time] may be non-null.
  ///
  /// If this lookup is based on [label], a cached profile will be returned from
  /// [_profilesByLabel], or null if one is not available.
  ///
  /// If this lookup is based on [time] and [_profilesByTime] contains a CPU
  /// profile for a time range that encompasses [time], a sub profile will be
  /// generated, cached in [_profilesByTime] and then returned. This method will
  /// return null if no profiles are cached for [time] or if a sub profile
  /// cannot be generated for [time].
  CpuProfileData? lookupProfile({String? label, TimeRange? time}) {
    assert((label == null) != (time == null));

    if (label != null) {
      return _profilesByLabel[label];
    }

    if (!time!.isWellFormed) return null;

    // If we have a profile for a time range encompassing [time], then we can
    // generate and cache the profile for [time] without needing to pull data
    // from the vm service.
    _maybeGenerateSubProfile(time);
    return _profilesByTime[time];
  }

  void storeProfile(CpuProfileData profile, {String? label, TimeRange? time}) {
    assert((label == null) != (time == null));
    if (label != null) {
      _profilesByLabel[label] = profile;
      return;
    }
    _profilesByTime[time!] = profile;
  }

  void _maybeGenerateSubProfile(TimeRange time) {
    if (_profilesByTime.containsKey(time)) return;
    final encompassingTimeRange = _encompassingTimeRange(time);
    if (encompassingTimeRange != null) {
      final encompassingProfile = _profilesByTime[encompassingTimeRange]!;
      final subProfile = CpuProfileData.subProfile(encompassingProfile, time);
      _profilesByTime[time] = subProfile;
    }
  }

  TimeRange? _encompassingTimeRange(TimeRange time) {
    int shortestDurationMicros = maxJsInt;
    TimeRange? encompassingTimeRange;
    for (final t in _profilesByTime.keys) {
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
    _profilesByTime.clear();
    _profilesByLabel.clear();
  }
}

class _CpuProfileTimelineTree {
  factory _CpuProfileTimelineTree.fromCpuSamples(
    vm_service.CpuSamples cpuSamples,
  ) {
    final root = _CpuProfileTimelineTree._fromIndex(cpuSamples, kRootIndex);
    _CpuProfileTimelineTree current;
    // TODO(bkonyi): handle truncated?
    for (final sample in cpuSamples.samples ?? []) {
      current = root;
      // Build an inclusive trie.
      for (final index in sample.stack!.reversed) {
        current = current._getChild(index);
      }
      _timelineTreeExpando[sample] = current;
    }
    return root;
  }

  _CpuProfileTimelineTree._fromIndex(this.samples, this.index);

  static final _timelineTreeExpando = Expando<_CpuProfileTimelineTree>();
  static const kRootIndex = -1;
  static const kNoFrameId = -1;
  final vm_service.CpuSamples samples;
  final int index;
  int frameId = kNoFrameId;

  String? get name => samples.functions![index].function.name;

  String? get className {
    final function = samples.functions![index].function;
    if (function is vm_service.FuncRef) {
      final owner = function.owner;
      if (owner is vm_service.ClassRef) {
        return owner.name;
      }
    }
    return null;
  }

  String? get resolvedUrl => samples.functions![index].resolvedUrl;

  int? get sourceLine {
    final function = samples.functions![index].function;
    try {
      return function.location?.line;
    } catch (_) {
      // Fail gracefully if `function` has no getter `location` (for example, if
      // the function is an instance of [NativeFunction]) or generally if
      // `function.location.line` throws an exception.
      return null;
    }
  }

  final children = <_CpuProfileTimelineTree>[];

  static _CpuProfileTimelineTree? getTreeFromSample(
    vm_service.CpuSample sample,
  ) =>
      _timelineTreeExpando[sample];

  _CpuProfileTimelineTree _getChild(int index) {
    final length = children.length;
    int i;
    for (i = 0; i < length; ++i) {
      final child = children[i];
      final childIndex = child.index;
      if (childIndex == index) {
        return child;
      }
      if (childIndex > index) {
        break;
      }
    }
    final child = _CpuProfileTimelineTree._fromIndex(samples, index);
    if (i < length) {
      children.insert(i, child);
    } else {
      children.add(child);
    }
    return child;
  }
}
