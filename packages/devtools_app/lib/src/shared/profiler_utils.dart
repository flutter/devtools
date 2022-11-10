// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../primitives/trees.dart';
import '../primitives/utils.dart';

mixin ProfilableDataMixin<T extends TreeNode<T>> on TreeNode<T> {
  ProfileMetaData get profileMetaData;

  String get displayName;

  /// How many cpu samples for which this frame is a leaf.
  int exclusiveSampleCount = 0;

  int get inclusiveSampleCount {
    final inclusiveSampleCountLocal = _inclusiveSampleCount;
    if (inclusiveSampleCountLocal != null) {
      return inclusiveSampleCountLocal;
    }
    return calculateInclusiveSampleCount();
  }

  /// How many cpu samples this frame is included in.
  int? _inclusiveSampleCount;

  set inclusiveSampleCount(int? count) => _inclusiveSampleCount = count;

  late double totalTimeRatio =
      safeDivide(inclusiveSampleCount, profileMetaData.sampleCount);

  late Duration totalTime = Duration(
    microseconds:
        (totalTimeRatio * profileMetaData.time!.duration.inMicroseconds)
            .round(),
  );

  late double selfTimeRatio =
      safeDivide(exclusiveSampleCount, profileMetaData.sampleCount);

  late Duration selfTime = Duration(
    microseconds:
        (selfTimeRatio * profileMetaData.time!.duration.inMicroseconds).round(),
  );

  double get inclusiveSampleRatio => safeDivide(
        inclusiveSampleCount,
        profileMetaData.sampleCount,
      );

  double get exclusiveSampleRatio => safeDivide(
        exclusiveSampleCount,
        profileMetaData.sampleCount,
      );

  /// Returns the number of samples this data node is a part of.
  ///
  /// This will be equal to the number of leaf nodes under this data node.
  int calculateInclusiveSampleCount() {
    int count = exclusiveSampleCount;
    for (int i = 0; i < children.length; i++) {
      final child = children[i] as ProfilableDataMixin<T>;
      count += child.inclusiveSampleCount;
    }
    _inclusiveSampleCount = count;
    return _inclusiveSampleCount!;
  }

  T deepCopy();

  @visibleForTesting
  String profileAsString() {
    final buf = StringBuffer();
    _format(buf, '  ');
    return buf.toString();
  }

  void _format(StringBuffer buf, String indent) {
    buf.writeln(
      '$indent$displayName - children: ${children.length} - excl: '
              '$exclusiveSampleCount - incl: $inclusiveSampleCount'
          .trimRight(),
    );
    for (T child in children) {
      (child as ProfilableDataMixin<T>)._format(buf, '  $indent');
    }
  }
}

class ProfileMetaData {
  const ProfileMetaData({
    required this.sampleCount,
    required this.time,
  });

  final int sampleCount;

  final TimeRange? time;
}

/// Process for converting a [ProfilableDataMixin] into a bottom-up
/// representation of the profile.
///
/// [rootedAtTags] specifies whether or not the top-down tree is rooted
/// at synthetic nodes representing user / VM tags.
class BottomUpTransformer<T extends ProfilableDataMixin<T>> {
  List<T> bottomUpRootsFor({
    required T topDownRoot,
    required void Function(List<T>) mergeSamples,
    // TODO(bkonyi): can this take a list instead of a single root?
    required bool rootedAtTags,
  }) {
    List<T> bottomUpRoots;
    // If the top-down tree has synthetic tag nodes as its roots, we need to
    // skip the synthetic nodes when inverting the tree and re-insert them at
    // the root.
    if (rootedAtTags) {
      bottomUpRoots = <T>[];
      for (final tagRoot in topDownRoot.children) {
        final root = tagRoot.shallowCopy() as T;

        // Generate bottom up roots for each child of the synthetic tag node
        // and insert them into the new synthetic tag node, [root].
        for (final child in tagRoot.children) {
          root.addAllChildren(
            generateBottomUpRoots(
              node: child,
              currentBottomUpRoot: null,
              bottomUpRoots: <T>[],
            ),
          );
        }

        // Cascade sample counts only for the non-tag nodes as the tag nodes
        // are synthetic and we'll calculate the counts for the tag nodes
        // later.
        root.children.forEach(cascadeSampleCounts);
        mergeSamples(root.children);
        bottomUpRoots.add(root);
      }
    } else {
      bottomUpRoots = generateBottomUpRoots(
        node: topDownRoot,
        currentBottomUpRoot: null,
        bottomUpRoots: <T>[],
      );

      // Set the bottom up sample counts for each sample.
      bottomUpRoots.forEach(cascadeSampleCounts);

      // Merge samples when possible starting at the root (the leaf node of the
      // original sample).
      mergeSamples(bottomUpRoots);
    }

    if (rootedAtTags) {
      // Calculate the total time for each tag root. The sum of the inclusive
      // times for each child for the tag node is the total time spent with the
      // given tag active.
      for (final tagRoot in bottomUpRoots) {
        tagRoot._inclusiveSampleCount = tagRoot.children.fold<int>(
          0,
          (prev, e) => prev + e._inclusiveSampleCount!,
        );
      }
    }

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
