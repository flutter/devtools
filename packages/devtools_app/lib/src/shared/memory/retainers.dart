// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

typedef IsRetainer = bool Function(int index);
typedef References = List<int> Function(int index);
typedef ShallowSize = int Function(int index);

typedef ShortestRetainersResult = ({
  /// Retainer for each object in the graph.
  ///
  /// 0 means no-retainer.
  /// Null is not used for no-retainer to save memory footprint.
  List<int> retainers,
  List<int>? retainedSizes,
});

/// Finds shortest retainers for each object in the graph.
///
/// Object at index 0 is sentinel and should not retain other objects.
ShortestRetainersResult findShortestRetainers({
  required int graphSize,
  required int rootIndex,
  required IsRetainer isRetainer,
  required References refs,
  required ShallowSize shallowSize,
  bool calculateSizes = true,
}) {
  assert(refs(0).isEmpty);
  assert(
    rootIndex != 0,
    'Root index should not be 0, it is reserved for no-retainer.',
  );

  final retainers = Uint32List(graphSize);
  Uint32List? retainedSizes;
  if (calculateSizes) {
    retainedSizes = Uint32List(graphSize);
    retainedSizes[rootIndex] = shallowSize(rootIndex);
  }

  // Array of all objects where the best distance from root is n.
  // n starts with 0 and increases by 1 on each step of the algorithm.
  // The objects are ends of the graph cut.
  // See description of cut:
  // https://en.wikipedia.org/wiki/Cut_(graph_theory)
  // On each step the algorithm moves the cut one step further from the root.
  var cut = [rootIndex];

  while (cut.isNotEmpty) {
    final nextCut = <int>[];
    for (final index in cut) {
      for (final ref in refs(index)) {
        if (ref == 0 || retainers[ref] != 0) continue;
        retainers[ref] = index;

        if (isRetainer(ref)) {
          retainedSizes?[ref] = shallowSize(ref);
          continue;
        }

        if (retainedSizes != null) {
          _addRetainedSize(
            index: ref,
            retainedSizes: retainedSizes,
            retainers: retainers,
            shallowSize: shallowSize,
          );
        }
        nextCut.add(ref);
      }
    }
    cut = nextCut;
  }

  return (retainers: retainers, retainedSizes: retainedSizes);
}

/// Assuming the object is leaf, initializes its retained size
/// and adds the size to each shortest retainer recursively.
void _addRetainedSize({
  required int index,
  required Uint32List retainedSizes,
  required Uint32List retainers,
  required ShallowSize shallowSize,
}) {
  final addedSize = shallowSize(index);
  retainedSizes[index] = addedSize;

  while (retainers[index] > 0) {
    index = retainers[index];
    retainedSizes[index] += addedSize;
  }
}
