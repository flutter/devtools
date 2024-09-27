// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

/// Returns true if the given object can retain other objects from garbage collection.
typedef IsWeak = bool Function(int index);

/// List of references for the given object.
typedef References = List<int> Function(int index);

/// Shallow size of the given object.
typedef ShallowSize = int Function(int index);

typedef ShortestRetainersResult = ({
  /// Retainer for each object in the graph.
  ///
  /// When a value at index i is 0, it means the object at index i
  /// has no retainers.
  /// Null is not used for no-retainer to save memory footprint.
  List<int> retainers,

  /// Retained size for each object in the graph.
  ///
  /// If an object is unreachable, its retained size is 0.
  List<int>? retainedSizes,
});

/// Index of the sentinel object.
const _sentinelIndex = 0;

/// Finds shortest retainers for each object in the graph.
///
/// Index 0 is reserved for sentinel object.
/// The sentinel object should not have size and references.
ShortestRetainersResult findShortestRetainers({
  required int graphSize,
  required int rootIndex,
  required IsWeak isWeak,
  required References refs,
  required ShallowSize shallowSize,
  bool calculateSizes = true,
}) {
  assert(refs(_sentinelIndex).isEmpty);
  assert(
    shallowSize(_sentinelIndex) <= 0,
    'Sentinel should have size 0 or -1 (not defined), but size is ${shallowSize(_sentinelIndex)}.',
  );
  assert(
    rootIndex != _sentinelIndex,
    'Root index should not be $_sentinelIndex, it is reserved for no-retainer.',
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
        if (ref == _sentinelIndex || retainers[ref] != 0) continue;
        retainers[ref] = index;
        retainedSizes?[ref] = shallowSize(ref);

        if (retainedSizes != null) {
          _addRetainedSize(
            index: ref,
            retainedSizes: retainedSizes,
            retainers: retainers,
            shallowSize: shallowSize,
          );
        }
        if (!isWeak(ref)) nextCut.add(ref);
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
