// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../primitives/utils.dart';
import 'cpu_profile_model.dart';

/// Process for composing [CpuProfileData] into a structured tree of
/// [CpuStackFrame]'s.
class CpuProfileTransformer {
  /// Number of stack frames we will process in each batch.
  static const _defaultBatchSize = 100;

  /// Notifies with the current progress value of transforming CPU profile data.
  ///
  /// This value should sit between 0.0 and 1.0.
  ValueListenable<double> get progressNotifier => _progressNotifier;
  final _progressNotifier = ValueNotifier<double>(0.0);

  late int _stackFramesCount;

  List<String?>? _stackFrameKeys;

  List<CpuStackFrame>? _stackFrameValues;

  int _stackFramesProcessed = 0;

  String? _activeProcessId;

  Future<void> processData(
    CpuProfileData cpuProfileData, {
    required String processId,
  }) async {
    // Do not process this data if it has already been processed.
    if (cpuProfileData.processed) return;

    // Reset the transformer before processing.
    reset();

    _activeProcessId = processId;
    _stackFramesCount = cpuProfileData.stackFrames.length;
    _stackFrameKeys = cpuProfileData.stackFrames.keys.toList();
    _stackFrameValues = cpuProfileData.stackFrames.values.toList();

    // At minimum, process the data in 4 batches to smooth the appearance of
    // the progress indicator.
    final quarterBatchSize = (_stackFramesCount / 4).round();
    final batchSize = math.min(
      _defaultBatchSize,
      quarterBatchSize == 0 ? 1 : quarterBatchSize,
    );

    // Use batch processing to maintain a responsive UI.
    while (_stackFramesProcessed < _stackFramesCount) {
      _processBatch(batchSize, cpuProfileData, processId: processId);
      _progressNotifier.value = _stackFramesProcessed / _stackFramesCount;

      // Await a small delay to give the UI thread a chance to update the
      // progress indicator. Use a longer delay than the default (0) so that the
      // progress indicator will look smoother.
      await delayForBatchProcessing(micros: 5000);

      if (processId != _activeProcessId) {
        throw ProcessCancelledException();
      }
    }

    _setExclusiveSampleCountsAndTags(cpuProfileData);
    cpuProfileData.processed = true;

    // TODO(kenz): investigate why this assert is firing again.
    // https://github.com/flutter/devtools/issues/1529.
//    assert(
//      cpuProfileData.profileMetaData.sampleCount ==
//          cpuProfileData.cpuProfileRoot.inclusiveSampleCount,
//      'SampleCount from response (${cpuProfileData.profileMetaData.sampleCount})'
//      ' != sample count from root '
//      '(${cpuProfileData.cpuProfileRoot.inclusiveSampleCount})',
//    );

    // Reset the transformer after processing.
    reset();
  }

  void _processBatch(
    int batchSize,
    CpuProfileData cpuProfileData, {
    required String processId,
  }) {
    final batchEnd =
        math.min(_stackFramesProcessed + batchSize, _stackFramesCount);
    for (int i = _stackFramesProcessed; i < batchEnd; i++) {
      if (processId != _activeProcessId) {
        throw ProcessCancelledException();
      }
      final key = _stackFrameKeys![i];
      final value = _stackFrameValues![i];
      final stackFrame = cpuProfileData.stackFrames[key]!;
      final parent = cpuProfileData.stackFrames[value.parentId];
      _processStackFrame(stackFrame, parent, cpuProfileData);
      _stackFramesProcessed++;
    }
  }

  void _processStackFrame(
    CpuStackFrame stackFrame,
    CpuStackFrame? parent,
    CpuProfileData cpuProfileData,
  ) {
    if (parent == null) {
      // [stackFrame] is the root of a new cpu sample. Add it as a child of
      // [cpuProfile].
      cpuProfileData.cpuProfileRoot.addChild(stackFrame);
    } else {
      parent.addChild(stackFrame);
    }
  }

  void _setExclusiveSampleCountsAndTags(CpuProfileData cpuProfileData) {
    for (CpuSample sample in cpuProfileData.cpuSamples) {
      final leafId = sample.leafId;
      final stackFrame = cpuProfileData.stackFrames[leafId];
      assert(
        stackFrame != null,
        'No StackFrame found for id $leafId. If you see this assertion, please '
        'export the timeline trace and send to kenzieschmoll@google.com. Note: '
        'you must export the timeline immediately after the AssertionError is '
        'thrown.',
      );
      if (stackFrame != null) {
        stackFrame.exclusiveSampleCount++;
        final userTag = sample.userTag;
        if (userTag != null) {
          stackFrame.incrementTagSampleCount(userTag);
        }
      }
    }
  }

  void reset() {
    _activeProcessId = null;
    _stackFramesProcessed = 0;
    _stackFrameKeys = null;
    _stackFrameValues = null;
    _progressNotifier.value = 0.0;
  }

  void dispose() {
    _progressNotifier.dispose();
  }
}

// TODO(kenz): move this into a shared file for use with the TimelineEvent
// class.
/// Process for converting a [ProfilableDataMixin] into a bottom-up
/// representation of the profile.
class BottomUpTransformer<T extends ProfilableDataMixin<T>> {
  List<T> bottomUpRootsFor({
    required T topDownRoot,
    required void Function(List<T>) mergeSamples,
  }) {
    final bottomUpRoots = generateBottomUpRoots(
      node: topDownRoot,
      currentBottomUpRoot: null,
      bottomUpRoots: <T>[],
    );

    // Set the bottom up sample counts for each sample.
    bottomUpRoots.forEach(cascadeSampleCounts);

    // Merge samples when possible starting at the root (the leaf node of the
    // original sample).
    mergeSamples(bottomUpRoots);

    return bottomUpRoots;
  }

  /// Returns the roots for a bottom up representation of a
  /// [ProfilableDataMixin] node.
  ///
  /// Each root is a leaf from the original [ProfilableDataMixin] tree, and its
  /// children will be the reverse stack of the original profile sample. The
  /// stack returned will not be merged to combine common roots, and the sample
  /// counts will not reflect the bottom up sample counts. These steps will
  /// occur later in the bottom-up conversion process.
  @visibleForTesting
  List<T> generateBottomUpRoots({
    required T node,
    required T? currentBottomUpRoot,
    required List<T> bottomUpRoots,
  }) {
    final copy = node.shallowCopy() as T;

    if (currentBottomUpRoot != null) {
      copy.addChild(currentBottomUpRoot.deepCopy());
    }

    // [copy] is the new root of the bottom up stack.
    currentBottomUpRoot = copy;

    if (node.exclusiveSampleCount > 0) {
      // This node is a leaf node, meaning it is a bottom up root.
      bottomUpRoots.add(currentBottomUpRoot);
    }
    for (final child in node.children.cast<T>()) {
      generateBottomUpRoots(
        node: child,
        currentBottomUpRoot: currentBottomUpRoot,
        bottomUpRoots: bottomUpRoots,
      );
    }
    return bottomUpRoots;
  }

  /// Sets sample counts of [node] and all children to [exclusiveSampleCount].
  ///
  /// This is necessary for the transformation of a [ProfilableDataMixin] to its
  /// bottom-up representation. This is an intermediate step between
  /// [generateBottomUpRoots] and the [mergeSamples] callback passed to
  /// [bottomUpRootsFor].
  @visibleForTesting
  void cascadeSampleCounts(T node) {
    node.inclusiveSampleCount = node.exclusiveSampleCount;
    for (final child in node.children.cast<T>()) {
      child.exclusiveSampleCount = node.exclusiveSampleCount;
      cascadeSampleCounts(child);
    }
  }
}

/// Merges CPU profile roots that share a common call stack (starting at the
/// root).
///
/// Ex. C               C                     C
///      -> B             -> B        -->      -> B
///          -> A             -> D                 -> A
///                                                -> D
///
/// At the time this method is called, we assume we have a list of roots with
/// accurate inclusive/exclusive sample counts.
void mergeCpuProfileRoots(List<CpuStackFrame> roots) {
  // Loop through a copy of [roots] so that we can remove nodes from [roots]
  // once we have merged them.
  final List<CpuStackFrame> rootsCopy = List.from(roots);
  for (CpuStackFrame root in rootsCopy) {
    if (!roots.contains(root)) {
      // We have already merged [root] and removed it from [roots]. Do not
      // attempt to merge again.
      continue;
    }

    final matchingRoots =
        roots.where((other) => other.matches(root) && other != root).toList();
    if (matchingRoots.isEmpty) {
      continue;
    }

    for (CpuStackFrame match in matchingRoots) {
      match.children.forEach(root.addChild);
      root.exclusiveSampleCount += match.exclusiveSampleCount;
      root.inclusiveSampleCount += match.inclusiveSampleCount;
      roots.remove(match);
      mergeCpuProfileRoots(root.children);
    }
  }

  for (CpuStackFrame root in roots) {
    root.index = roots.indexOf(root);
  }
}
