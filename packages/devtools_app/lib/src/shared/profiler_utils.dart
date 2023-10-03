// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/debugger/codeview_controller.dart';
import '../screens/debugger/debugger_screen.dart';
import '../screens/vm_developer/vm_developer_common_widgets.dart';
import 'globals.dart';
import 'primitives/trees.dart';
import 'primitives/utils.dart';

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
        skipRoot: true,
      );

      // Set the bottom up sample counts for each sample.
      bottomUpRoots.forEach(cascadeSampleCounts);

      // Merge samples when possible starting at the root (the leaf node of the
      // original sample).
      mergeSamples(bottomUpRoots);
    }

    if (rootedAtTags) {
      // Calculate the total time for each tag root. The sum of the exclusive
      // times for each child for the tag node is the total time spent with the
      // given tag active.
      for (final tagRoot in bottomUpRoots) {
        tagRoot.inclusiveSampleCount = tagRoot.children.fold<int>(
          0,
          (prev, e) => prev + e.exclusiveSampleCount,
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
    bool skipRoot = false,
  }) {
    if (skipRoot && node.isRoot) {
      // When [skipRoot] is true, do not include the root node at the leaf of
      // each bottom up tree. This is to avoid having the 'all' node at the
      // at the bottom of each bottom up path.
    } else {
      // Inclusive and exclusive sample counts are copied by default.
      final copy = node.shallowCopy() as T;

      if (currentBottomUpRoot != null) {
        copy.addChild(currentBottomUpRoot.deepCopy());
      }

      // [copy] is the new root of the bottom up stack.
      currentBottomUpRoot = copy;

      if (node.exclusiveSampleCount > 0) {
        // This node is a leaf node, meaning that one or more CPU samples
        // contain [currentBottomUpRoot] as the top stack frame. This means it
        // is a bottom up root.
        bottomUpRoots.add(currentBottomUpRoot);
      } else {
        // If [currentBottomUpRoot] is not a bottom up root, the inclusive count
        // should be set to null. This will allow the inclusive count to be
        // recalculated now that this node is part of its parent's bottom up
        // tree, not its own.
        currentBottomUpRoot.inclusiveSampleCount = null;
      }
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

  /// Cascades the [exclusiveSampleCount] and [inclusiveSampleCount] of [node]
  /// to all of its children (recursive).
  ///
  /// This is necessary for the transformation of a [ProfilableDataMixin] to its
  /// bottom-up representation. This is an intermediate step between
  /// [generateBottomUpRoots] and the [mergeSamples] callback passed to
  /// [bottomUpRootsFor].
  @visibleForTesting
  void cascadeSampleCounts(T node) {
    for (final child in node.children.cast<T>()) {
      child.exclusiveSampleCount = node.exclusiveSampleCount;
      child.inclusiveSampleCount = node.inclusiveSampleCount;
      cascadeSampleCounts(child);
    }
  }
}

class MethodAndSourceDisplay extends StatelessWidget {
  const MethodAndSourceDisplay({
    required this.methodName,
    required this.packageUri,
    required this.sourceLine,
    required this.isSelected,
    this.displayInRow = true,
    super.key,
  });

  static const separator = ' - ';

  final String methodName;

  final String packageUri;

  final int? sourceLine;

  final bool isSelected;

  final bool displayInRow;

  @override
  Widget build(BuildContext context) {
    final fontStyle = Theme.of(context).fixedFontStyle;
    final sourceTextSpans = <TextSpan>[];
    final packageUriWithSourceLine = uriWithSourceLine(packageUri, sourceLine);

    if (packageUriWithSourceLine.isNotEmpty) {
      sourceTextSpans.add(const TextSpan(text: separator));

      final sourceDisplay = '($packageUriWithSourceLine)';
      final script = scriptManager.scriptRefForUri(packageUri);
      final showSourceAsLink = script != null;
      if (showSourceAsLink) {
        sourceTextSpans.add(
          VmServiceObjectLink(
            object: script,
            textBuilder: (_) => sourceDisplay,
            onTap: (e) {
              GoRouter.of(context).goNamed(
                DebuggerScreen.id,
                extra: CodeViewSourceLocationNavigationState(
                  script: script,
                  line: sourceLine!,
                ),
              );
            },
          ).buildTextSpan(context),
        );
      } else {
        sourceTextSpans.add(
          TextSpan(
            text: sourceDisplay,
            style: fontStyle,
          ),
        );
      }
    }
    final richText = RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        text: methodName,
        style: fontStyle,
        children: sourceTextSpans,
      ),
    );
    if (displayInRow) {
      return Row(
        children: [
          richText,
          // Include this [Spacer] so that the clickable [VmServiceObjectLink]
          // does not extend all the way to the end of the row.
          const Spacer(),
        ],
      );
    }
    return richText;
  }
}

String uriWithSourceLine(String uri, int? sourceLine) =>
    '$uri${sourceLine != null ? ':$sourceLine' : ''}';
