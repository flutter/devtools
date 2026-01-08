// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../../shared/charts/flame_chart.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/primitives/trace_event.dart';
import '../../shared/primitives/trees.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/search.dart';
import '../../shared/utils/profiler_utils.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'cpu_profile_transformer.dart';
import 'cpu_profiler_controller.dart';

final _log = Logger('lib/src/screens/profiler/cpu_profile_model');

/// The root ID is associated with an artificial frame / node that is the root
/// of all stacks, regardless of entrypoint. This should never be seen in the
/// [CpuProfileData].
const _kRootId = 0;

/// A convenience wrapper for managing CPU profiles with both function and code
/// profile views.
///
/// `codeProfile` is null for CPU profiles collected when advanced developer
/// mode is disabled.
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
    final function = CpuProfileData.filterFrom(
      original.functionProfile,
      callback,
    );
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
    final function = CpuProfileData.subProfile(
      original.functionProfile,
      subTimeRange,
    );
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
      code = CpuProfileData.withTagRoots(codeProfile, tagType);
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
  /// `codeProfile` is null when advanced developer mode is not enabled.
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
  /// `CpuProfilerViewType.code` as its parameter when advanced developer mode is
  /// disabled.
  CpuProfileData getActive(CpuProfilerViewType activeType) {
    if (activeType == CpuProfilerViewType.code &&
        !preferences.advancedDeveloperModeEnabled.value) {
      throw StateError(
        'Attempting to display a code profile with advanced developer mode '
        'disabled.',
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
    if (codeProfile case final codeProfile?) {
      await transformer.processData(codeProfile, processId: processId);
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
  }) : cpuProfileRoot = CpuStackFrame.root(profileMetaData);

  factory CpuProfileData.fromJson(Map<String, Object?> json_) {
    if (json_.isEmpty) {
      return CpuProfileData.empty();
    }

    final json = _CpuProfileDataJson(json_);

    // All CPU samples.
    final samples = json.traceEvents ?? <CpuSampleEvent>[];

    // Sort the samples so we can compute the observed time difference between
    // each sample.
    samples.sort((a, b) => a.timestampMicros!.compareTo(b.timestampMicros!));

    // Prefer the approximate observed median time between samples over the
    // reported sample period.
    //
    // See https://github.com/flutter/devtools/pull/8941 for more information.
    final sampleTimestamps = samples
        .map((s) => s.timestampMicros)
        .nonNulls
        .toList();
    final samplePeriod =
        observedSamplePeriod(sampleTimestamps) ?? json.samplePeriod ?? 0;

    final timeOriginMicros = json.timeOriginMicros;
    final timeExtentMicros = json.timeExtentMicros;
    final profileMetaData = CpuProfileMetaData(
      sampleCount: json.sampleCount ?? 0,
      samplePeriod: samplePeriod,
      stackDepth: json.stackDepth ?? 0,
      time: (timeOriginMicros != null && timeExtentMicros != null)
          ? TimeRange.ofDuration(timeExtentMicros, start: timeOriginMicros)
          : null,
    );

    // Initialize all stack frames.
    final stackFrames = <String, CpuStackFrame>{};
    final stackFramesJson = json.stackFrames ?? const <String, Object?>{};
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
        .where((sample) => subTimeRange.contains(sample.timestampMicros!))
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
      final idMapping = <String, String>{rootId: tagId};

      tagProfile.stackFrames.forEach((k, v) {
        idMapping.putIfAbsent(k, () => '$isolateId-${nextId++}');
      });

      for (final sample in tagProfile.cpuSamples) {
        String? updatedId = idMapping[sample.leafId]!;
        samples.add(
          CpuSampleEvent(
            leafId: updatedId,
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

    final microsPerSample = originalData.profileMetaData.samplePeriod;
    final newSampleCount = samplesWithTag.length;
    final metaData = originalData.profileMetaData.copyWith(
      sampleCount: newSampleCount,
      // The start time is zero because only `TimeRange.duration` will matter
      // for this profile data, and the samples included in this data could be
      // sparse over the original profile's time range, so true start and end
      // times wouldn't be helpful.
      time: TimeRange(
        start: 0,
        end: microsPerSample.isInfinite
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
        final parentStackFrameJson = parentId != null
            ? originalData.stackFrames[parentId]
            : null;
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
      final sampleJson = Map<String, Object?>.of(sample.json);
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

    final originalTime = originalData.profileMetaData.measuredDuration;
    final microsPerSample =
        originalTime.inMicroseconds / originalData.profileMetaData.sampleCount;
    final updatedMetaData = originalData.profileMetaData.copyWith(
      sampleCount: filteredCpuSamples.length,
      // The start time is zero because only `TimeRange.duration` will matter
      // for this profile data, and the samples included in this data could be
      // sparse over the original profile's time range, so true start and end
      // times wouldn't be helpful.
      time: TimeRange(
        start: 0,
        end: microsPerSample.isInfinite || microsPerSample.isNaN
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

  factory CpuProfileData.empty() => CpuProfileData._(
    stackFrames: {},
    cpuSamples: [],
    profileMetaData: CpuProfileMetaData(
      sampleCount: 0,
      samplePeriod: 0,
      stackDepth: 0,
      time: null,
    ),
    rootedAtTags: false,
  );

  /// Generates [CpuProfileData] from the provided [cpuSamples].
  ///
  /// [isolateId] The isolate id which was used to get the [cpuSamples].
  /// This will be used to tag the stack frames and trace events.
  /// [cpuSamples] The CPU samples that will be used to generate the [CpuProfileData]
  static Future<CpuProfileData> generateFromCpuSamples({
    required String isolateId,
    required vm_service.CpuSamples cpuSamples,
    bool buildCodeTree = false,
  }) async {
    // Note: Do not change the order of these function calls! Generating the
    // stack frames has a side effect of creating the timeline tree and
    // assigning frame IDs to every node, which the sample event conversion is
    // dependant upon.
    //
    // TODO(https://github.com/flutter/devtools/issues/9353): Refactor the
    // implementation to avoid the side effects described above.
    final profileMetaData = _createProfileMetadata(cpuSamples: cpuSamples);

    final stackFrames =
        await _CpuStackFrameGenerator(
          isolateId: isolateId,
          cpuSamples: cpuSamples,
          profileMetaData: profileMetaData,
        ).generate(
          treeRoot: _CpuProfileTimelineTree.fromCpuSamples(
            cpuSamples,
            asCodeProfileTimelineTree: buildCodeTree,
          ),
        );

    final sampleEvents = _convertSamplesToEvents(
      cpuSamples: cpuSamples,
      isolateId: isolateId,
    );

    return CpuProfileData._(
      stackFrames: stackFrames,
      cpuSamples: sampleEvents,
      profileMetaData: profileMetaData,
      rootedAtTags: false,
    );
  }

  /// Creates a [CpuProfileMetaData] object using the given [cpuSamples].
  static CpuProfileMetaData _createProfileMetadata({
    required vm_service.CpuSamples cpuSamples,
  }) {
    final samplePeriod = _calculateSamplePeriod(cpuSamples: cpuSamples);

    return CpuProfileMetaData(
      sampleCount: cpuSamples.sampleCount ?? 0,
      samplePeriod: samplePeriod ?? 0,
      stackDepth: cpuSamples.maxStackDepth ?? 0,
      time:
          cpuSamples.timeExtentMicros != null &&
              cpuSamples.timeOriginMicros != null
          ? TimeRange.ofDuration(
              cpuSamples.timeExtentMicros!,
              start: cpuSamples.timeOriginMicros!,
            )
          : null,
    );
  }

  /// Calculates the median sample period for a the given [cpuSamples].
  static int? _calculateSamplePeriod({
    required vm_service.CpuSamples cpuSamples,
  }) {
    final samples = cpuSamples.samples;
    if (samples == null) return cpuSamples.samplePeriod;

    // Sort the sample timestamps so we can compute the observed time difference
    // between each sample.
    final sampleTimestamps = samples.map((s) => s.timestamp).nonNulls.toList();
    sampleTimestamps.sort();

    // Prefer the approximate observed median time between samples over the
    // reported sample period.
    //
    // See https://github.com/flutter/devtools/pull/8941 for more information.
    return observedSamplePeriod(sampleTimestamps) ?? cpuSamples.samplePeriod;
  }

  /// Converts the `samples` from a [vm_service.CpuSamples] object to a list of
  /// [CpuSampleEvent]s.
  static List<CpuSampleEvent> _convertSamplesToEvents({
    required vm_service.CpuSamples cpuSamples,
    required String isolateId,
  }) {
    final sampleEvents = <CpuSampleEvent>[];

    for (final sample in cpuSamples.samples ?? <vm_service.CpuSample>[]) {
      final node = _CpuProfileTimelineTree.getTreeFromSample(sample);
      // Skip the root because it is a synthetic node.
      if (node == null || node.frameId == _kRootId) {
        continue;
      }

      final nodeId = node.id(isolateId);
      sampleEvents.add(
        CpuSampleEvent(
          leafId: nodeId,
          userTag: sample.userTag,
          vmTag: sample.vmTag,
          traceJson: {
            'ph': 'P', // kind = sample event
            'name': '', // Blank to keep about:tracing happy
            'pid': cpuSamples.pid,
            'tid': sample.tid,
            'ts': sample.timestamp,
            'cat': 'Dart',
            CpuProfileData.stackFrameIdKey: nodeId,
            'args': {userTagKey: sample.userTag, vmTagKey: sample.vmTag},
          },
        ),
      );
    }

    return sampleEvents;
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

  final CpuStackFrame cpuProfileRoot;

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
      for (final rootChild in cpuProfileRoot.children) rootChild.deepCopy(),
    ];
  }

  List<CpuStackFrame>? _callTreeRoots;

  List<CpuStackFrame> get bottomUpRoots {
    if (!processed) return <CpuStackFrame>[];

    return _bottomUpRoots!;
  }

  Future<void> computeBottomUpRoots() async {
    assert(_bottomUpRoots == null);
    _bottomUpRoots = await BottomUpTransformer<CpuStackFrame>()
        .bottomUpRootsFor(
          topDownRoot: cpuProfileRoot,
          mergeSamples: mergeCpuProfileRoots,
          rootedAtTags: rootedAtTags,
        );
  }

  List<CpuStackFrame>? _bottomUpRoots;

  late final userTags = <String>{
    for (final cpuSample in cpuSamples)
      if (cpuSample.userTag case final userTag?) userTag,
  };

  late final vmTags = <String>{
    for (final cpuSample in cpuSamples)
      if (cpuSample.vmTag case final vmTag?) vmTag,
  };

  CpuStackFrame? selectedStackFrame;

  @override
  Map<String, Object?> toJson() => {
    'type': '_CpuProfileTimeline',
    _samplePeriodKey: profileMetaData.samplePeriod,
    _sampleCountKey: profileMetaData.sampleCount,
    _stackDepthKey: profileMetaData.stackDepth,
    _timeOriginKey: ?profileMetaData.time?.start,
    _timeExtentKey: ?profileMetaData.time?.duration.inMicroseconds,
    _stackFramesKey: stackFramesJson,
    _traceEventsKey: cpuSamples.map((sample) => sample.toJson).toList(),
  };

  bool get isEmpty => profileMetaData.sampleCount == 0;

  @visibleForTesting
  Map<String, Object?> get stackFramesJson => {
    for (final sf in stackFrames.values) ...sf.toJson,
  };
}

extension type _CpuProfileDataJson(Map<String, Object?> json) {
  int? get timeOriginMicros => json[CpuProfileData._timeOriginKey] as int?;
  int? get timeExtentMicros => json[CpuProfileData._timeExtentKey] as int?;
  int? get sampleCount => json[CpuProfileData._sampleCountKey] as int?;
  int? get samplePeriod => json[CpuProfileData._samplePeriodKey] as int?;
  int? get stackDepth => json[CpuProfileData._stackDepthKey] as int?;
  Map<String, Object?>? get stackFrames =>
      (json[CpuProfileData._stackFramesKey] as Map?)?.cast<String, Object?>();
  List<CpuSampleEvent>? get traceEvents =>
      (json[CpuProfileData._traceEventsKey] as List?)
          ?.cast<Map>()
          .map((trace) => trace.cast<String, Object?>())
          .map((trace) => CpuSampleEvent.fromJson(trace))
          .toList();
}

class CpuProfileMetaData extends ProfileMetaData {
  CpuProfileMetaData({
    required super.sampleCount,
    required super.samplePeriod,
    required this.stackDepth,
    required super.time,
  });

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
    required Map<String, Object?> traceJson,
  }) : super(traceJson);

  factory CpuSampleEvent.fromJson(Map<String, Object?> traceJson) {
    final leafId = traceJson[CpuProfileData.stackFrameIdKey]! as String;
    final args = (traceJson[ChromeTraceEvent.argsKey] as Map?)
        ?.cast<String, Object?>();
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

  Map<String, Object?> get toJson {
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

  /// The ids for all ancestors of this [CpuStackFrame].
  ///
  /// This method should only be called when the [CpuStackFrame] is part of a
  /// processed CPU profile.
  Iterable<String> get ancestorIds sync* {
    CpuStackFrame? next = this;
    while (next != null) {
      if (next.parentId case final parentId?) yield parentId;
      next = next.parent;
    }
  }

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

  bool get isNative => _isNative ??=
      id != CpuProfileData.rootId &&
      packageUri.isEmpty &&
      !name.startsWith(PackagePrefixes.flutterEngine) &&
      !isTag;

  bool? _isNative;

  bool get isDartCore => _isDartCore ??=
      packageUri.startsWith(PackagePrefixes.dart) &&
      !packageUri.startsWith(PackagePrefixes.dartUi);

  bool? _isDartCore;

  bool get isFlutterCore => _isFlutterCore ??=
      packageUri.startsWith(PackagePrefixes.flutterPackage) ||
      name.startsWith(PackagePrefixes.flutterEngine) ||
      packageUri.startsWith(PackagePrefixes.dartUi);

  bool? _isFlutterCore;

  @override
  String get tooltip {
    final String? prefix;
    if (isNative) {
      prefix = '[Native]';
    } else if (isDartCore) {
      prefix = '[Dart]';
    } else if (isFlutterCore) {
      prefix = '[Flutter]';
    } else if (isTag) {
      prefix = '[Tag]';
    } else {
      prefix = null;
    }
    final nameWithPrefix = [?prefix, name].join(' ');
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
  /// by default. Inclusive sample counts should only be copied as part of a
  /// deep copy of a tree.
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
    for (final child in children) {
      copy.addChild(child.deepCopy());
    }
    return copy;
  }

  /// Whether `this` stack frame matches another stack frame [other].
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
      CpuProfileData.parentIdKey: ?parentId,
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
  CpuProfilePair? lookupProfile({String? label, TimeRange? time}) {
    assert((label == null) != (time == null));

    if (label != null) {
      return _profilesByLabel[label];
    }

    if (time == null) return null;

    // If we have a profile for a time range encompassing [time], then we can
    // generate and cache the profile for [time] without needing to pull data
    // from the vm service.
    _maybeGenerateSubProfile(time);
    return _profilesByTime[time];
  }

  void storeProfile(CpuProfilePair profile, {String? label, TimeRange? time}) {
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
      final stack = asCodeProfileTimelineTree
          ? sample.codeStack
          : sample.stack!;
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
    final function = samples.functions?[index].function;
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

  String? get resolvedUrl {
    if (isCodeTree) {
      if (_function is vm_service.FuncRef?) {
        // TODO(bkonyi): not sure if this is a resolved URL or not, but it's not
        // critical since this is only displayed when advanced developer mode is
        // enabled.
        return (_function as vm_service.FuncRef?)?.location?.script?.uri;
      }
    } else {
      final functions = samples.functions;
      if (functions == null || index >= functions.length) return null;
      return functions[index].resolvedUrl;
    }

    return null;
  }

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
  ) => _timelineTreeExpando[sample];

  String id(String isolateId) {
    // Assertion to guard that _CpuStackFrameGenerator.generate has been called
    // before getting the frame ID.
    assert(
      frameId != kNoFrameId,
      'Frame ID does not exist, have the stack frames been generated?',
    );
    return frameId == _kRootId ? CpuProfileData.rootId : '$isolateId-$frameId';
  }

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
    final child = _CpuProfileTimelineTree._fromIndex(
      samples,
      index,
      isCodeTree,
    );
    if (i < length) {
      children.insert(i, child);
    } else {
      children.add(child);
    }
    return child;
  }
}

/// A generator class for creating a set of [CpuStackFrame]s from a
/// [vm_service.CpuSamples] object.
///
/// This class is responsible for traversing the call stacks of a CPU profile,
/// creating a [CpuStackFrame] for each unique frame, and assigning a unique
/// ID to each. It also resolves the package URI for each stack frame and
/// handles fetching missing package URIs from the [serviceConnection] if
/// necessary.
class _CpuStackFrameGenerator {
  _CpuStackFrameGenerator({
    required this.isolateId,
    required this.cpuSamples,
    required this.profileMetaData,
  });

  final String isolateId;
  final vm_service.CpuSamples cpuSamples;
  final CpuProfileMetaData profileMetaData;

  final _stackFrames = <String, CpuStackFrame>{};
  final _stackFramesWaitingOnPackageUri = <CpuStackFrame>[];
  final _urisWithoutPackageUri = <String>{};
  int _nextFrameId = _kRootId;

  /// Generates a map of [String] IDs to [CpuStackFrame] objects.
  ///
  /// Refer to [_CpuProfileTimelineTree.id] for how the ID keys are
  /// generated.
  Future<Map<String, CpuStackFrame>> generate({
    required _CpuProfileTimelineTree treeRoot,
  }) async {
    // If the stack frames have already been generated, simply return them.
    if (_stackFrames.isNotEmpty) return _stackFrames;

    // Recursively generate the stack frames map.
    _processNode(currentNode: treeRoot, parentNode: null);

    // Add any missing package URIs to the stack frames.
    await _fetchAndUpdateMissingPackageUris();

    return _stackFrames;
  }

  /// Recursively calls [_addStackFrameForNode] on all nodes in the timeline
  /// tree, starting with the [currentNode].
  void _processNode({
    required _CpuProfileTimelineTree currentNode,
    required _CpuProfileTimelineTree? parentNode,
  }) {
    final frameId = _nextFrameId++;
    currentNode.frameId = frameId;

    // Skip creating a stack frame for the root node, since it is a synthetic
    // node and has no parent.
    if (parentNode != null) {
      _addStackFrameForNode(currentNode: currentNode, parentNode: parentNode);
    }

    for (final childNode in currentNode.children) {
      _processNode(currentNode: childNode, parentNode: currentNode);
    }
  }

  /// Creates a [CpuStackFrame] for the [currentNode] and adds it to the
  /// [_stackFrames] map.
  void _addStackFrameForNode({
    required _CpuProfileTimelineTree currentNode,
    required _CpuProfileTimelineTree parentNode,
  }) {
    final id = currentNode.id(isolateId);
    final verboseName = _nameForStackFrame(currentNode);
    final rawUrl = currentNode.resolvedUrl ?? '';
    final packageUri = serviceConnection.serviceManager.resolvedUriManager
        .lookupPackageUri(isolateId, rawUrl);

    final stackFrame = CpuStackFrame(
      id: id,
      name: getSimpleStackFrameName(verboseName),
      verboseName: verboseName,
      category: 'Dart',
      rawUrl: rawUrl,
      packageUri: packageUri ?? rawUrl,
      sourceLine: currentNode.sourceLine,
      parentId: parentNode.id(isolateId),
      profileMetaData: profileMetaData,
      isTag: false,
    );
    _stackFrames[id] = stackFrame;

    // If the package URI was not found, keep track of it so that we can bulk
    // fetch all package URIs and update the stack frame after all frames have
    // been processed.
    if (rawUrl.isNotEmpty && packageUri == null) {
      _stackFramesWaitingOnPackageUri.add(stackFrame);
      _urisWithoutPackageUri.add(rawUrl);
    }
  }

  /// Returns a user-friendly name for a stack frame from a
  /// [_CpuProfileTimelineTree] node `current`.
  ///
  /// For regular methods, this will return a name in the form of
  /// `className.methodName`.
  ///
  /// For anonymous closures, this will attempt to find the owner of the
  /// closure and return a name in the form of `owner.closureName`.
  String? _nameForStackFrame(_CpuProfileTimelineTree current) {
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

      return nameParts.nonNulls.join('.');
    }
    return current.name;
  }

  /// Bulk fetches any package URIs that could not be found when processing the
  /// [_stackFrames], then updates each stack frame that was missing the package
  /// URI.
  Future<void> _fetchAndUpdateMissingPackageUris() async {
    if (_stackFramesWaitingOnPackageUri.isEmpty) return;

    _log.fine(
      'Fetching missing URIs for ${_urisWithoutPackageUri.length} packages.',
    );
    await serviceConnection.serviceManager.resolvedUriManager.fetchPackageUris(
      isolateId,
      _urisWithoutPackageUri.toList(),
    );

    _log.fine(
      'Updating ${_stackFramesWaitingOnPackageUri.length} with package URIs.',
    );
    for (final stackFrame in _stackFramesWaitingOnPackageUri) {
      final rawUrl = stackFrame.rawUrl;
      final packageUri = serviceConnection.serviceManager.resolvedUriManager
          .lookupPackageUri(isolateId, rawUrl);
      if (packageUri != null) {
        _stackFrames[stackFrame.id] = stackFrame.shallowCopy(
          packageUri: packageUri,
        );
      }
    }

    _stackFramesWaitingOnPackageUri.clear();
    _urisWithoutPackageUri.clear();
  }
}

/// Efficiently approximates the observed sample period of [timestamps], by
/// calculating the approximate median time difference between each timestamp.
///
/// The [timestamps] must be sorted before calling this function.
///
/// If there are fewer than 100 timestamps, returns `null`, because there isn't
/// enough data to be confident about the observed sample period.
///
/// This does not return the exact median, but instead the median of medians
/// of groups of 5 elements, which makes the algorithm much more efficient.
@visibleForTesting
int? observedSamplePeriod(List<int> timestamps) {
  if (timestamps.length < 100) return null;

  // To compute the median efficiently, we compute the median of groups of 5
  // elements, and then grab the median of those medians by sorting, which
  // brings us a linear time complexity while retaining high accuracy.
  final mediansOfGroupsOf5 = <int>[];
  for (var i = 1; i + 5 < timestamps.length; i += 5) {
    // The time diff between the sample at index and the previous sample.
    int diff(int index) {
      final result = timestamps[index] - timestamps[index - 1];
      assert(result >= 0);
      return result;
    }

    mediansOfGroupsOf5.add(
      _median5(diff(i), diff(i + 1), diff(i + 2), diff(i + 3), diff(i + 4)),
    );
  }
  mediansOfGroupsOf5.sort();
  return mediansOfGroupsOf5[(mediansOfGroupsOf5.length / 2).floor()];
}

/// Computes the median of 5 numbers without allocating a list
/// or actually sorting all the numbers.
int _median5(int a, int b, int c, int d, int e) {
  while (true) {
    if (c < a) {
      (a, c) = (c, a);
    } else if (c < b) {
      (b, c) = (c, b);
    } else if (c > d) {
      (c, d) = (d, c);
    } else if (c > e) {
      (c, e) = (e, c);
    } else {
      return c;
    }
  }
}
