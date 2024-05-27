// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../../shared/charts/flame_chart.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/primitives/trace_event.dart';
import '../../shared/primitives/trees.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/profiler_utils.dart';
import '../../shared/ui/search.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'cpu_profile_transformer.dart';
import 'cpu_profiler_controller.dart';

final _log = Logger('lib/src/screens/profiler/cpu_profile_model');

/// A convenience wrapper for managing CPU profiles with both function and code
/// profile views.
///
/// `codeProfile` is null for CPU profiles collected when VM developer mode is
/// disabled.
class CpuProfilePair {
  const CpuProfilePair({
    required this.functionProfile,
    required this.codeProfile,
  });

  /// Builds a new [CpuProfilePair] from `original`, only consisting of samples
  /// associated with the user tag `tag`.
  ///
  /// `original` does not need to be `processed` when calling this constructor.
  factory CpuProfilePair.fromUserTag(CpuProfilePair original, String tag) {
    final function = CpuProfileData.fromUserTag(original.functionProfile, tag);
    CpuProfileData? code;
    if (original.codeProfile != null) {
      code = CpuProfileData.fromUserTag(original.codeProfile!, tag);
    }
    return CpuProfilePair(functionProfile: function, codeProfile: code);
  }

  /// Builds a new [CpuProfilePair] from `original`, only containing frames
  /// that meet the conditions set out by `callback`.
  ///
  /// `original` does not need to be `processed` when calling this constructor.
  factory CpuProfilePair.filterFrom(
    CpuProfilePair original,
    bool Function(CpuStackFrame) callback,
  ) {
    final function =
        CpuProfileData.filterFrom(original.functionProfile, callback);
    CpuProfileData? code;
    if (original.codeProfile != null) {
      code = CpuProfileData.filterFrom(original.codeProfile!, callback);
    }
    return CpuProfilePair(functionProfile: function, codeProfile: code);
  }

  /// Builds a new [CpuProfilePair] from `original`, only consisting of samples
  /// collected within [subTimeRange].
  ///
  /// `original` does not need to be `processed` when calling this constructor.
  factory CpuProfilePair.subProfile(
    CpuProfilePair original,
    TimeRange subTimeRange,
  ) {
    final function =
        CpuProfileData.subProfile(original.functionProfile, subTimeRange);
    CpuProfileData? code;
    if (original.codeProfile != null) {
      code = CpuProfileData.subProfile(original.codeProfile!, subTimeRange);
    }
    return CpuProfilePair(functionProfile: function, codeProfile: code);
  }

  factory CpuProfilePair.withTagRoots(
    CpuProfilePair original,
    CpuProfilerTagType tagType,
  ) {
    final function = CpuProfileData.withTagRoots(
      original.functionProfile,
      tagType,
    );
    final codeProfile = original.codeProfile;
    CpuProfileData? code;
    if (codeProfile != null) {
      code = CpuProfileData.withTagRoots(
        codeProfile,
        tagType,
      );
    }
    return CpuProfilePair(functionProfile: function, codeProfile: code);
  }

  /// Represents the function view of the CPU profile. This view displays
  /// function objects rather than code objects, which can potentially contain
  /// multiple inlined functions.
  final CpuProfileData functionProfile;

  /// Represents the code view of the CPU profile, which displays code objects
  /// rather than functions. Individual code objects can contain code for
  /// multiple functions if they are inlined by the compiler.
  ///
  /// `codeProfile` is null when VM developer mode is not enabled.
  final CpuProfileData? codeProfile;

  // Both function and code profiles will have the same metadata, processing
  // state, and number of samples, so we can just use the values from
  // `functionProfile` since it is always available.

  /// Returns `true` if there are any samples in this CPU profile.
  bool get isEmpty => functionProfile.isEmpty;

  /// Returns `true` if [process] has been invoked.
  bool get processed => functionProfile.processed;

  /// Returns the metadata associated with this CPU profile.
  CpuProfileMetaData get profileMetaData => functionProfile.profileMetaData;

  /// Returns the [CpuProfileData] that should be displayed for the currently
  /// selected profile view.
  ///
  /// This method will throw a [StateError] when given
  /// `CpuProfilerViewType.code` as its parameter when VM developer mode is
  /// disabled.
  CpuProfileData getActive(CpuProfilerViewType activeType) {
    if (activeType == CpuProfilerViewType.code &&
        !preferences.vmDeveloperModeEnabled.value) {
      throw StateError(
        'Attempting to display a code profile with VM developer mode disabled.',
      );
    }
    return activeType == CpuProfilerViewType.function
        ? functionProfile
        : codeProfile!;
  }

  /// Builds up the function profile and code profile (if non-null).
  ///
  /// This method must be called before either `functionProfile` or
  /// `codeProfile` can be used.
  Future<void> process({
    required CpuProfileTransformer transformer,
    required String processId,
  }) async {
    await transformer.processData(functionProfile, processId: processId);
    if (codeProfile != null) {
      await transformer.processData(codeProfile!, processId: processId);
    }
  }
}

/// Data model for DevTools CPU profile.
class CpuProfileData with Serializable {
  CpuProfileData._({
    required this.stackFrames,
    required this.cpuSamples,
    required this.profileMetaData,
    required this.rootedAtTags,
  }) {
    _cpuProfileRoot = CpuStackFrame.root(profileMetaData);
  }

  factory CpuProfileData.fromJson(Map<String, dynamic> json_) {
    final json = _CpuProfileDataJson(json_);
    final profileMetaData = CpuProfileMetaData(
      sampleCount: json.sampleCount ?? 0,
      samplePeriod: json.samplePeriod ?? 0,
      stackDepth: json.stackDepth ?? 0,
      time: (json.timeOriginMicros != null && json.timeExtentMicros != null)
          ? (TimeRange()
            ..start = Duration(microseconds: json.timeOriginMicros!)
            ..end = Duration(
              microseconds: json.timeOriginMicros! + json.timeExtentMicros!,
            ))
          : null,
    );

    // Initialize all stack frames.
    final stackFrames = <String, CpuStackFrame>{};
    final Map<String, Object?> stackFramesJson =
        jsonDecode(jsonEncode(json.stackFrames ?? <String, Object?>{}));
    for (final entry in stackFramesJson.entries) {
      final stackFrameJson = entry.value as Map<String, Object?>;
      final resolvedUrl = (stackFrameJson[resolvedUrlKey] as String?) ?? '';
      final packageUri =
          (stackFrameJson[resolvedPackageUriKey] as String?) ?? resolvedUrl;
      final name = getSimpleStackFrameName(stackFrameJson[nameKey] as String?);
      final stackFrame = CpuStackFrame(
        id: entry.key,
        name: name,
        verboseName: stackFrameJson[nameKey] as String?,
        category: stackFrameJson[categoryKey] as String?,
        // If the user is on a version of Flutter where resolvedUrl is not
        // included in the response, this will be null. If the frame is a native
        // frame, the this will be the empty string.
        rawUrl: resolvedUrl,
        packageUri: packageUri,
        sourceLine: stackFrameJson[sourceLineKey] as int?,
        parentId: (stackFrameJson[parentIdKey] as String?) ?? rootId,
        profileMetaData: profileMetaData,
        isTag: false,
      );
      stackFrames[stackFrame.id] = stackFrame;
    }

    // Initialize all CPU samples.
    final samples = json.traceEvents ?? [];

    return CpuProfileData._(
      stackFrames: stackFrames,
      cpuSamples: samples,
      profileMetaData: profileMetaData,
      rootedAtTags: false,
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

    final subStackFrames = <String, CpuStackFrame>{};
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
      rootedAtTags: superProfile.rootedAtTags,
    );
  }

  /// Generate a cpu profile from [originalData] where the profile is broken
  /// down for each tag of the given [tagType].
  ///
  /// [originalData] does not need to be [processed] to run this operation.
  factory CpuProfileData.withTagRoots(
    CpuProfileData originalData,
    CpuProfilerTagType tagType,
  ) {
    final useUserTags = tagType == CpuProfilerTagType.user;
    final tags = <String>{
      for (final sample in originalData.cpuSamples)
        useUserTags ? sample.userTag! : sample.vmTag!,
    };

    final tagProfiles = <String, CpuProfileData>{
      for (final tag in tags)
        tag: CpuProfileData._fromTag(originalData, tag, tagType),
    };

    final metaData = originalData.profileMetaData.copyWith();

    final stackFrames = <String, CpuStackFrame>{};
    final samples = <CpuSampleEvent>[];

    int nextId = 1;

    for (final tagProfileEntry in tagProfiles.entries) {
      final tag = tagProfileEntry.key;
      final tagProfile = tagProfileEntry.value;
      if (tagProfile.cpuSamples.isEmpty) {
        continue;
      }
      final isolateId = tagProfile.cpuSamples.first.leafId.split('-').first;
      final tagId = '$isolateId-${nextId++}';
      stackFrames[tagId] = CpuStackFrame._(
        id: tagId,
        name: tag,
        verboseName: tag,
        category: 'Dart',
        rawUrl: '',
        packageUri: '',
        sourceLine: null,
        parentId: null,
        profileMetaData: metaData,
        isTag: true,
      );
      final idMapping = <String, String>{
        rootId: tagId,
      };

      tagProfile.stackFrames.forEach((k, v) {
        idMapping.putIfAbsent(k, () => '$isolateId-${nextId++}');
      });

      for (final sample in tagProfile.cpuSamples) {
        String? updatedId = idMapping[sample.leafId];
        samples.add(
          CpuSampleEvent(
            leafId: updatedId!,
            userTag: sample.userTag,
            vmTag: sample.vmTag,
            traceJson: sample.toJson,
          ),
        );
        var currentStackFrame = tagProfile.stackFrames[sample.leafId];
        while (currentStackFrame != null) {
          final parentId = idMapping[currentStackFrame.parentId];
          stackFrames[updatedId!] = currentStackFrame.shallowCopy(
            id: updatedId,
            copySampleCounts: false,
            profileMetaData: metaData,
            parentId: parentId,
          );
          final parentStackFrameJson = parentId != null
              ? originalData.stackFrames[currentStackFrame.parentId]
              : null;
          updatedId = parentId;
          currentStackFrame = parentStackFrameJson;
        }
      }
    }
    return CpuProfileData._(
      stackFrames: stackFrames,
      cpuSamples: samples,
      profileMetaData: metaData,
      rootedAtTags: true,
    );
  }

  /// Generate a cpu profile from [originalData] where each sample contains the
  /// userTag [tag].
  ///
  /// [originalData] does not need to be [processed] to run this operation.
  factory CpuProfileData.fromUserTag(CpuProfileData originalData, String tag) {
    return CpuProfileData._fromTag(originalData, tag, CpuProfilerTagType.user);
  }

  factory CpuProfileData._fromTag(
    CpuProfileData originalData,
    String tag,
    CpuProfilerTagType type,
  ) {
    final useUserTag = type == CpuProfilerTagType.user;
    final tags = useUserTag ? originalData.userTags : originalData.vmTags;
    if (!tags.contains(tag)) {
      return CpuProfileData.empty();
    }

    final samplesWithTag = originalData.cpuSamples
        .where((sample) => (useUserTag ? sample.userTag : sample.vmTag) == tag)
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

    final stackFramesWithTag = <String, CpuStackFrame>{};

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
      rootedAtTags: false,
    );
  }

  /// Generate a cpu profile from [originalData] where each stack frame meets
  /// the condition specified by [includeFilter].
  ///
  /// [originalData] does not need to be [processed] to run this operation.
  // TODO(https://github.com/flutter/devtools/issues/5203): ensure we can filter
  // from an already filtered profile. This throws a null exception.
  factory CpuProfileData.filterFrom(
    CpuProfileData originalData,
    bool Function(CpuStackFrame) includeFilter,
  ) {
    final filteredCpuSamples = <CpuSampleEvent>[];
    void includeSampleOrWalkUp(
      CpuSampleEvent sample,
      Map<String, Object?> sampleJson,
      CpuStackFrame stackFrame,
    ) {
      if (includeFilter(stackFrame)) {
        filteredCpuSamples.add(
          CpuSampleEvent(
            leafId: stackFrame.id,
            userTag: sample.userTag,
            vmTag: sample.vmTag,
            traceJson: sampleJson,
          ),
        );
      }
      // TODO(kenz): investigate why [stackFrame.parentId] is sometimes
      // missing.
      else if (stackFrame.parentId != CpuProfileData.rootId &&
          originalData.stackFrames.containsKey(stackFrame.parentId)) {
        final parent = originalData.stackFrames[stackFrame.parentId]!;
        includeSampleOrWalkUp(sample, sampleJson, parent);
      }
    }

    for (final sample in originalData.cpuSamples) {
      final sampleJson = Map<String, Object?>.from(sample.json);
      final leafStackFrame = originalData.stackFrames[sample.leafId]!;
      includeSampleOrWalkUp(sample, sampleJson, leafStackFrame);
    }

    final filteredStackFrames = <String, CpuStackFrame>{};

    String? filteredParentStackFrameId(CpuStackFrame? candidateParentFrame) {
      if (candidateParentFrame == null) return null;

      if (includeFilter(candidateParentFrame)) {
        return candidateParentFrame.id;
      }
      // TODO(kenz): investigate why [stackFrame.parentId] is sometimes
      // missing.
      else if (candidateParentFrame.parentId != CpuProfileData.rootId &&
          originalData.stackFrames.containsKey(candidateParentFrame.parentId)) {
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
      rootedAtTags: originalData.rootedAtTags,
    );
  }

  factory CpuProfileData.empty() => CpuProfileData.fromJson({});

  /// Generates [CpuProfileData] from the provided [CpuSamples].
  ///
  /// [isolateId] The isolate id which was used to get the [cpuSamples].
  /// This will be used to tag the stack frames and trace events.
  /// [cpuSamples] The CPU samples that will be used to generate the [CpuProfileData]
  static Future<CpuProfileData> generateFromCpuSamples({
    required String isolateId,
    required vm_service.CpuSamples cpuSamples,
    bool buildCodeTree = false,
  }) async {
    // The root ID is associated with an artificial frame / node that is the root
    // of all stacks, regardless of entrypoint. This should never be seen in the
    // final output from this method.
    const int kRootId = 0;
    final traceObject = <String, Object?>{
      CpuProfileData._sampleCountKey: cpuSamples.sampleCount,
      CpuProfileData._samplePeriodKey: cpuSamples.samplePeriod,
      CpuProfileData._stackDepthKey: cpuSamples.maxStackDepth,
      CpuProfileData._timeOriginKey: cpuSamples.timeOriginMicros,
      CpuProfileData._timeExtentKey: cpuSamples.timeExtentMicros,
      CpuProfileData._stackFramesKey: cpuSamples.generateStackFramesJson(
        isolateId: isolateId,
        // We want to ensure that if [kRootId] ever changes, this change is
        // propagated to [cpuSamples.generateStackFramesJson].
        // ignore: avoid_redundant_argument_values
        kRootId: kRootId,
        buildCodeTree: buildCodeTree,
      ),
      CpuProfileData._traceEventsKey: [],
    };

    // Build the trace events.
    for (final sample in cpuSamples.samples ?? <vm_service.CpuSample>[]) {
      final tree = _CpuProfileTimelineTree.getTreeFromSample(sample)!;
      // Skip the root.
      if (tree.frameId == kRootId) {
        continue;
      }
      (traceObject[CpuProfileData._traceEventsKey]! as List<Object?>).add({
        'ph': 'P', // kind = sample event
        'name': '', // Blank to keep about:tracing happy
        'pid': cpuSamples.pid,
        'tid': sample.tid,
        'ts': sample.timestamp,
        'cat': 'Dart',
        CpuProfileData.stackFrameIdKey: '$isolateId-${tree.frameId}',
        'args': {
          if (sample.userTag != null) userTagKey: sample.userTag,
          if (sample.vmTag != null) vmTagKey: sample.vmTag,
        },
      });
    }

    await _addPackageUrisToTraceObject(isolateId, traceObject);

    return CpuProfileData.fromJson(traceObject);
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
    Map<String, Object?> traceObject,
  ) async {
    final stackFrameMap = traceObject[CpuProfileData._stackFramesKey] as Map;
    final stackFrames = stackFrameMap.values.cast<Map<String, Object?>>();
    final stackFramesWaitingOnPackageUri = <Map<String, Object?>>[];
    final urisWithoutPackageUri = <String>{};
    for (final stackFrameJson in stackFrames) {
      final resolvedUrl =
          stackFrameJson[CpuProfileData.resolvedUrlKey] as String?;
      if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
        final packageUri = serviceConnection.serviceManager.resolvedUriManager
            .lookupPackageUri(isolateId, resolvedUrl);
        if (packageUri != null) {
          stackFrameJson[CpuProfileData.resolvedPackageUriKey] = packageUri;
        } else {
          stackFramesWaitingOnPackageUri.add(stackFrameJson);
          urisWithoutPackageUri.add(resolvedUrl);
        }
      }
    }

    await serviceConnection.serviceManager.resolvedUriManager.fetchPackageUris(
      isolateId,
      urisWithoutPackageUri.toList(),
    );

    for (var stackFrameJson in stackFramesWaitingOnPackageUri) {
      final resolvedUri =
          stackFrameJson[CpuProfileData.resolvedUrlKey] as String;
      final packageUri = serviceConnection.serviceManager.resolvedUriManager
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
  static const _stackFramesKey = 'stackFrames';
  static const _traceEventsKey = 'traceEvents';
  static const _sampleCountKey = 'sampleCount';
  static const _stackDepthKey = 'stackDepth';
  static const _samplePeriodKey = 'samplePeriod';
  static const _timeOriginKey = 'timeOriginMicros';
  static const _timeExtentKey = 'timeExtentMicros';
  static const userTagKey = 'userTag';
  static const vmTagKey = 'vmTag';

  final Map<String, CpuStackFrame> stackFrames;

  final List<CpuSampleEvent> cpuSamples;

  final CpuProfileMetaData profileMetaData;

  /// `true` if the CpuProfileData has tag-based roots.
  ///
  /// This value is used during the bottom-up transformation to ensure that the
  /// tag-based roots are kept at the root of the resulting bottom-up tree.
  final bool rootedAtTags;

  /// Marks whether this data has already been processed.
  bool processed = false;

  List<CpuStackFrame> get callTreeRoots {
    if (!processed) return <CpuStackFrame>[];
    return _callTreeRoots ??= [
      // Don't display the root node.
      ..._cpuProfileRoot.children.map((e) => e.deepCopy()),
    ];
  }

  List<CpuStackFrame>? _callTreeRoots;

  List<CpuStackFrame> get bottomUpRoots {
    if (!processed) return <CpuStackFrame>[];

    _bottomUpRoots ??= BottomUpTransformer<CpuStackFrame>().bottomUpRootsFor(
      topDownRoot: _cpuProfileRoot,
      mergeSamples: mergeCpuProfileRoots,
      rootedAtTags: rootedAtTags,
    );

    return _bottomUpRoots!;
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

  Iterable<String> get vmTags {
    if (_vmTags != null) {
      return _vmTags!;
    }
    final tags = <String>{};
    for (final cpuSample in cpuSamples) {
      final tag = cpuSample.vmTag;
      if (tag != null) {
        tags.add(tag);
      }
    }
    return _vmTags = tags;
  }

  Iterable<String>? _userTags;
  Iterable<String>? _vmTags;

  late final CpuStackFrame _cpuProfileRoot;

  CpuStackFrame? selectedStackFrame;

  @override
  Map<String, Object?> toJson() => {
        'type': '_CpuProfileTimeline',
        _samplePeriodKey: profileMetaData.samplePeriod,
        _sampleCountKey: profileMetaData.sampleCount,
        _stackDepthKey: profileMetaData.stackDepth,
        if (profileMetaData.time?.start != null)
          _timeOriginKey: profileMetaData.time!.start!.inMicroseconds,
        if (profileMetaData.time?.duration != null)
          _timeExtentKey: profileMetaData.time!.duration.inMicroseconds,
        _stackFramesKey: stackFramesJson,
        _traceEventsKey: cpuSamples.map((sample) => sample.toJson).toList(),
      };

  bool get isEmpty => profileMetaData.sampleCount == 0;

  @visibleForTesting
  Map<String, Object?> get stackFramesJson {
    final framesJson = <String, Object?>{};
    for (final sf in stackFrames.values) {
      framesJson.addAll(sf.toJson);
    }
    return framesJson;
  }
}

extension type _CpuProfileDataJson(Map<String, dynamic> json) {
  int? get timeOriginMicros => json[CpuProfileData._timeOriginKey];
  int? get timeExtentMicros => json[CpuProfileData._timeExtentKey];
  int? get sampleCount => json[CpuProfileData._sampleCountKey];
  int? get samplePeriod => json[CpuProfileData._samplePeriodKey];
  int? get stackDepth => json[CpuProfileData._stackDepthKey];
  Map<String, Object?>? get stackFrames =>
      (json[CpuProfileData._stackFramesKey] as Map?)?.cast<String, Object?>();
  List<CpuSampleEvent>? get traceEvents =>
      (json[CpuProfileData._traceEventsKey] as List?)
          ?.cast<Map>()
          .map((trace) => trace.cast<String, Object?>())
          .map((trace) => CpuSampleEvent.fromJson(trace))
          .toList()
          .cast<CpuSampleEvent>();
}

class CpuProfileMetaData extends ProfileMetaData {
  CpuProfileMetaData({
    required super.sampleCount,
    required this.samplePeriod,
    required this.stackDepth,
    required super.time,
  });

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

class CpuSampleEvent extends ChromeTraceEvent {
  CpuSampleEvent({
    required this.leafId,
    required this.userTag,
    required this.vmTag,
    required Map<String, dynamic> traceJson,
  }) : super(traceJson);

  factory CpuSampleEvent.fromJson(Map<String, dynamic> traceJson) {
    final leafId = traceJson[CpuProfileData.stackFrameIdKey];
    final args =
        (traceJson[ChromeTraceEvent.argsKey] as Map?)?.cast<String, Object?>();
    final userTag = args?[CpuProfileData.userTagKey] as String?;
    final vmTag = args?[CpuProfileData.vmTagKey] as String?;
    return CpuSampleEvent(
      leafId: leafId,
      userTag: userTag,
      vmTag: vmTag,
      traceJson: traceJson,
    );
  }

  final String leafId;

  final String? userTag;
  final String? vmTag;

  Map<String, dynamic> get toJson {
    // [leafId] is the source of truth for the leaf id of this sample.
    super.json[CpuProfileData.stackFrameIdKey] = leafId;
    return super.json;
  }
}

class CpuStackFrame extends TreeNode<CpuStackFrame>
    with
        ProfilableDataMixin<CpuStackFrame>,
        SearchableDataMixin,
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
    required bool isTag,
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
      isTag: isTag,
    );
  }

  factory CpuStackFrame.root(CpuProfileMetaData profileMetaData) =>
      CpuStackFrame._(
        id: CpuProfileData.rootId,
        name: CpuProfileData.rootName,
        verboseName: CpuProfileData.rootName,
        category: 'Dart',
        rawUrl: '',
        packageUri: '',
        sourceLine: null,
        profileMetaData: profileMetaData,
        parentId: null,
        isTag: false,
      );

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
    required this.isTag,
  }) : _profileMetaData = profileMetaData;

  final String id;

  final String name;

  final String? verboseName;

  final String? category;

  final String rawUrl;

  final String packageUri;

  String get packageUriWithSourceLine =>
      uriWithSourceLine(packageUri, sourceLine);

  final int? sourceLine;

  final String? parentId;

  /// The set of ids for all ancestors of this [CpuStackFrame].
  ///
  /// This is late and final, so it will only be created once for performance
  /// reasons. This method should only be called when the [CpuStackFrame] is
  /// part of a processed CPU profile.
  late final Set<String> ancestorIds = {
    if (parentId != null) parentId!,
    ...parent?.ancestorIds ?? {},
  };

  @override
  CpuProfileMetaData get profileMetaData => _profileMetaData;

  final CpuProfileMetaData _profileMetaData;

  @override
  String get displayName => name;

  /// Set to `true` if this stack frame is a synthetic frame representing a
  /// user or VM tag.
  ///
  /// These synthetic frames are inserted at the root of the profile when
  /// samples are being grouped by tag.
  final bool isTag;

  bool get isNative => _isNative ??= id != CpuProfileData.rootId &&
      packageUri.isEmpty &&
      !name.startsWith(PackagePrefixes.flutterEngine) &&
      !isTag;

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
    } else if (isTag) {
      prefix = '[Tag]';
    }
    final nameWithPrefix = [prefix, name].join(' ');
    return [
      nameWithPrefix,
      durationText(totalTime),
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
      isTag: isTag,
    );
    if (copySampleCounts) {
      copy
        ..exclusiveSampleCount = exclusiveSampleCount
        ..inclusiveSampleCount = inclusiveSampleCount;
    }
    return copy;
  }

  /// Returns a deep copy from this stack frame down to the leaves of the tree.
  ///
  /// The returned copy stack frame will have a null parent.
  @override
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
      name == other.name &&
      rawUrl == other.rawUrl &&
      category == other.category &&
      sourceLine == other.sourceLine;

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return name.caseInsensitiveContains(regExpSearch) ||
        packageUri.caseInsensitiveContains(regExpSearch);
  }

  Map<String, Object?> get toJson => {
        id: {
          CpuProfileData.nameKey: verboseName,
          CpuProfileData.categoryKey: category,
          CpuProfileData.resolvedUrlKey: rawUrl,
          CpuProfileData.resolvedPackageUriKey: packageUri,
          CpuProfileData.sourceLineKey: sourceLine,
          if (parentId != null) CpuProfileData.parentIdKey: parentId,
        },
      };

  @override
  String toString() {
    final buf = StringBuffer();
    buf.write('$name ');
    // TODO(kenz): use a number of fractionDigits that better matches the
    // resolution of the stack frame.
    buf.write('- ${durationText(totalTime, fractionDigits: 2)} ');
    buf.write('($inclusiveSampleCount ');
    buf.write(inclusiveSampleCount == 1 ? 'sample' : 'samples');
    buf.write(', ${percent(totalTimeRatio)})');
    return buf.toString();
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
  final _profilesByLabel = <String, CpuProfilePair>{};

  /// Store of CPU profiles keyed by a time range.
  ///
  /// These time ranges are allowed to overlap.
  final _profilesByTime = <TimeRange, CpuProfilePair>{};

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
  CpuProfilePair? lookupProfile({
    String? label,
    TimeRange? time,
  }) {
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

  void storeProfile(
    CpuProfilePair profile, {
    String? label,
    TimeRange? time,
  }) {
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
      final subProfile = CpuProfilePair.subProfile(encompassingProfile, time);
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

  void debugPrintKeys() {
    _log.info('_profilesByLabel: ${_profilesByLabel.keys}');
    _log.info('_profilesByTime: ${_profilesByTime.keys}');
  }
}

class _CpuProfileTimelineTree {
  factory _CpuProfileTimelineTree.fromCpuSamples(
    vm_service.CpuSamples cpuSamples, {
    bool asCodeProfileTimelineTree = false,
  }) {
    final root = _CpuProfileTimelineTree._fromIndex(
      cpuSamples,
      kRootIndex,
      asCodeProfileTimelineTree,
    );
    _CpuProfileTimelineTree current;
    // TODO(bkonyi): handle truncated?
    for (final sample in cpuSamples.samples ?? <vm_service.CpuSample>[]) {
      current = root;
      final stack =
          asCodeProfileTimelineTree ? sample.codeStack : sample.stack!;
      // Build an inclusive trie.
      for (final index in stack.reversed) {
        current = current._getChild(index);
      }
      _timelineTreeExpando[sample] = current;
    }
    return root;
  }

  _CpuProfileTimelineTree._fromIndex(this.samples, this.index, this.isCodeTree);

  static final _timelineTreeExpando = Expando<_CpuProfileTimelineTree>();
  static const kRootIndex = -1;
  static const kNoFrameId = -1;
  final vm_service.CpuSamples samples;
  final int index;
  final bool isCodeTree;
  int frameId = kNoFrameId;

  Object? get _function {
    if (isCodeTree) {
      return _code.function!;
    }
    final function = samples.functions![index].function;
    if (function is vm_service.FuncRef ||
        function is vm_service.NativeFunction) {
      return function;
    }
    return null;
  }

  vm_service.CodeRef get _code => samples.codes[index].code!;

  String? get name {
    if (isCodeTree) return _code.name;
    switch (_function.runtimeType) {
      case const (vm_service.FuncRef):
        return (_function as vm_service.FuncRef?)?.name;
      case const (vm_service.NativeFunction):
        return (_function as vm_service.NativeFunction?)?.name;
    }
    return null;
  }

  String? get className {
    if (isCodeTree) return null;
    final function = _function;
    if (function is vm_service.FuncRef) {
      final owner = function.owner;
      if (owner is vm_service.ClassRef) {
        return owner.name;
      }
    }
    return null;
  }

  String? get resolvedUrl => isCodeTree && _function is vm_service.FuncRef?
      ?
      // TODO(bkonyi): not sure if this is a resolved URL or not, but it's not
      // critical since this is only displayed when VM developer mode is
      // enabled.
      (_function as vm_service.FuncRef?)?.location?.script?.uri
      : samples.functions![index].resolvedUrl;

  int? get sourceLine {
    final function = _function;
    try {
      if (function is vm_service.FuncRef?) {
        return function?.location?.line;
      }
      return null;
    } catch (_) {
      // Fail gracefully if `function.location.line` throws an exception.
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
    final child =
        _CpuProfileTimelineTree._fromIndex(samples, index, isCodeTree);
    if (i < length) {
      children.insert(i, child);
    } else {
      children.add(child);
    }
    return child;
  }
}

extension on vm_service.CpuSamples {
  Map<String, dynamic> generateStackFramesJson({
    required String isolateId,
    int kRootId = 0,
    bool buildCodeTree = false,
  }) {
    final traceObject = <String, Object?>{};
    int nextId = kRootId;

    String? nameForStackFrame(_CpuProfileTimelineTree current) {
      final className = current.className;
      if (className != null) {
        return '$className.${current.name}';
      }
      if (current.name == anonymousClosureName &&
          current._function is vm_service.FuncRef) {
        final nameParts = <String?>[current.name];

        final function = current._function as vm_service.FuncRef;
        var owner = function.owner;
        switch (owner.runtimeType) {
          case const (vm_service.FuncRef):
            owner = owner as vm_service.FuncRef;
            final functionName = owner.name;

            String? className;
            if (owner.owner is vm_service.ClassRef) {
              className = (owner.owner as vm_service.ClassRef).name;
            }

            nameParts.insertAll(0, [className, functionName]);
            break;
          case const (vm_service.ClassRef):
            final className = (owner as vm_service.ClassRef).name;
            nameParts.insert(0, className);
        }

        nameParts.removeWhere((element) => element == null);
        return nameParts.join('.');
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
        traceObject[key] = {
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

    final root = _CpuProfileTimelineTree.fromCpuSamples(
      this,
      asCodeProfileTimelineTree: buildCodeTree,
    );
    processStackFrame(current: root, parent: null);
    return traceObject;
  }
}
