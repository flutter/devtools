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
  /// stack returned will not be merged to combine common roots. Merging will
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
}
