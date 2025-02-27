// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../screens/debugger/codeview_controller.dart';
import '../../screens/debugger/debugger_screen.dart';
import '../../screens/vm_developer/vm_developer_common_widgets.dart';
import '../../shared/constants.dart';
import '../framework/routing.dart';
import '../globals.dart';
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

  late double totalTimeRatio = safeDivide(
    inclusiveSampleCount,
    profileMetaData.sampleCount,
  );

  late Duration totalTime = Duration(
    microseconds:
        (totalTimeRatio * profileMetaData.measuredDuration.inMicroseconds)
            .round(),
  );

  late double selfTimeRatio = safeDivide(
    exclusiveSampleCount,
    profileMetaData.sampleCount,
  );

  late Duration selfTime = Duration(
    microseconds:
        (selfTimeRatio * profileMetaData.measuredDuration.inMicroseconds)
            .round(),
  );

  double get inclusiveSampleRatio =>
      safeDivide(inclusiveSampleCount, profileMetaData.sampleCount);

  double get exclusiveSampleRatio =>
      safeDivide(exclusiveSampleCount, profileMetaData.sampleCount);

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
    for (final child in children) {
      (child as ProfilableDataMixin<T>)._format(buf, '  $indent');
    }
  }
}

class ProfileMetaData {
  const ProfileMetaData({
    required this.sampleCount,
    required this.samplePeriod,
    required this.time,
  });

  /// The total number of samples in this profile.
  final int sampleCount;

  /// The sample period for this profile in microseconds.
  final int samplePeriod;

  /// The time range of the entire profile.
  ///
  /// Note that there may be periods of time with no samples, so the duration
  /// of this time should not be used in any calculations for how long a given
  /// sample took, instead use [measuredDuration].
  final TimeRange? time;

  /// The amount of time measured by all the samples taken in this profile.
  ///
  /// This is different from [time] which is just the start to end time of the
  /// entire profile which includes time where no samples were taken.
  Duration get measuredDuration =>
      Duration(microseconds: sampleCount * samplePeriod);
}

/// Process for converting a [ProfilableDataMixin] into a bottom-up
/// representation of the profile.
///
/// [rootedAtTags] specifies whether or not the top-down tree is rooted
/// at synthetic nodes representing user / VM tags.
class BottomUpTransformer<T extends ProfilableDataMixin<T>> {
  Future<List<T>> bottomUpRootsFor({
    required T topDownRoot,
    required Future<void> Function(List<T>, {Stopwatch? stopwatch})
    mergeSamples,
    // TODO(bkonyi): can this take a list instead of a single root?
    required bool rootedAtTags,
  }) async {
    final watch = Stopwatch()..start();
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
            await generateBottomUpRoots(
              node: child,
              parent: null,
              bottomUpRoots: <T>[],
              stopwatch: watch,
            ),
          );
        }

        // Cascade sample counts only for the non-tag nodes as the tag nodes
        // are synthetic and we'll calculate the counts for the tag nodes
        // later.
        root.children.forEach(cascadeSampleCounts);
        await mergeSamples(root.children, stopwatch: watch);
        bottomUpRoots.add(root);
      }
    } else {
      bottomUpRoots = await generateBottomUpRoots(
        node: topDownRoot,
        parent: null,
        bottomUpRoots: <T>[],
        skipRoot: true,
        stopwatch: watch,
      );

      // Set the bottom up sample counts for each sample.
      bottomUpRoots.forEach(cascadeSampleCounts);

      // Merge samples when possible starting at the root (the leaf node of the
      // original sample).
      await mergeSamples(bottomUpRoots, stopwatch: watch);
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
  /// The [stopwatch] is used to chunk up work and try to avoid dropping frames,
  /// and doesn't need to be passed in from the outside.
  ///
  /// Each root is a leaf from the original [ProfilableDataMixin] tree, and its
  /// children will be the reverse stack of the original profile sample. The
  /// stack returned will not be merged to combine common roots, and the sample
  /// counts will not reflect the bottom up sample counts. These steps will
  /// occur later in the bottom-up conversion process.
  @visibleForTesting
  Future<List<T>> generateBottomUpRoots({
    required T node,
    required T? parent,
    required List<T> bottomUpRoots,
    bool skipRoot = false,
    Stopwatch? stopwatch,
  }) async {
    stopwatch ??= Stopwatch()..start();
    if (stopwatch.elapsedMilliseconds > frameBudgetMs * 0.5) {
      await delayToReleaseUiThread(micros: 5000);
      stopwatch.reset();
    }

    if (skipRoot && node.isRoot) {
      // When [skipRoot] is true, do not include the root node at the leaf of
      // each bottom up tree. This is to avoid having the 'all' node at the
      // at the bottom of each bottom up path.
    } else {
      // Inclusive and exclusive sample counts are copied by default.
      final copy = node.shallowCopy() as T;

      if (parent != null) {
        copy.addChild(parent);
      }

      if (node.exclusiveSampleCount > 0) {
        // This node is a leaf node, meaning that one or more CPU samples
        // contain it as the top stack frame. This means it is a bottom up root.
        //
        // Each bottom up root needs a deep copy of the entire tree reaching to
        // it.
        bottomUpRoots.add(copy.deepCopy());
      } else {
        // If the node is not a bottom up root, the inclusive count should be
        // set to null. This will allow the inclusive count to be recalculated
        // now that this node is part of its parent's bottom up tree, not its
        // own.
        copy.inclusiveSampleCount = null;
      }

      // [copy] is the new parent
      parent = copy;
    }
    for (final child in node.children.cast<T>()) {
      await generateBottomUpRoots(
        node: child,
        parent: parent,
        bottomUpRoots: bottomUpRoots,
        stopwatch: stopwatch,
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
    this.displayInRow = true,
    super.key,
  });

  static const separator = ' - ';

  final String methodName;

  final String packageUri;

  final int? sourceLine;

  final bool displayInRow;

  @override
  Widget build(BuildContext context) {
    final fontStyle = Theme.of(context).regularTextStyle;
    final sourceTextSpans = <TextSpan>[];
    final packageUriWithSourceLine = uriWithSourceLine(packageUri, sourceLine);

    if (packageUriWithSourceLine.isNotEmpty) {
      sourceTextSpans.add(const TextSpan(text: separator));

      final sourceDisplay = '($packageUriWithSourceLine)';
      final script = scriptManager.scriptRefForUri(packageUri);
      final showSourceAsLink =
          script != null && !offlineDataController.showingOfflineData.value;
      if (showSourceAsLink) {
        sourceTextSpans.add(
          VmServiceObjectLink(
            object: script,
            textBuilder: (_) => sourceDisplay,
            onTap: (e) {
              DevToolsRouterDelegate.of(context).navigate(
                DebuggerScreen.id,
                const {},
                CodeViewSourceLocationNavigationState(
                  script: script,
                  line: sourceLine!,
                ),
              );
            },
          ).buildTextSpan(context),
        );
      } else {
        sourceTextSpans.add(TextSpan(text: sourceDisplay, style: fontStyle));
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
      // Include this [Row] so that the clickable [VmServiceObjectLink]
      // does not extend all the way to the end of the row.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Flexible(child: richText)],
      );
    }
    return richText;
  }
}

String uriWithSourceLine(String uri, int? sourceLine) =>
    '$uri${sourceLine != null ? ':$sourceLine' : ''}';
