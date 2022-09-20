// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';

/// Sets the field retainer and retainedSize for each object in the [heap], that
/// has retaining path to the root.
void buildSpanningTree(AdaptedHeapData heap) {
  assert(!heap.isSpanningTreeBuilt);
  _setRetainers(heap);
  heap.isSpanningTreeBuilt = true;
  _verifyHeapIntegrity(heap);
}

/// The algorithm takes O(number of references in the heap).
void _setRetainers(AdaptedHeapData heap) {
  heap.root.retainer = -1;
  heap.root.retainedSize = heap.root.shallowSize;

  // Array of all objects where the best distance from root is n.
  // n starts with 0 and increases by 1 on each step of the algorithm.
  // The objects are ends of the graph cut.
  // See description of cut:
  // https://en.wikipedia.org/wiki/Cut_(graph_theory)
  // On each step the algorithm moves the cut one step further from the root.
  var cut = [heap.rootIndex];

  // On each step of algorithm we know that all nodes at distance n or closer to
  // root, has parent initialized.
  while (true) {
    final nextCut = <int>[];
    for (var r in cut) {
      final retainer = heap.objects[r];
      for (var c in retainer.references) {
        final child = heap.objects[c];

        if (child.retainer != null) continue;
        child.retainer = r;
        child.retainedSize = child.shallowSize;

        _propagateSize(child, heap);

        if (_isRetainer(child)) {
          nextCut.add(c);
        }
      }
    }
    if (nextCut.isEmpty) return;
    cut = nextCut;
  }
}

/// Assuming the [object] is leaf, initializes its retained size
/// and adds the size to all its retainers.
void _propagateSize(AdaptedHeapObject object, AdaptedHeapData heap) {
  assert(object.retainer != null);
  assert(object.retainedSize == object.shallowSize);
  final addedSize = object.shallowSize;

  while (object.retainer != -1) {
    final retainer = heap.objects[object.retainer!];
    assert(retainer.retainer != null);
    assert(retainer != object);
    retainer.retainedSize = retainer.retainedSize! + addedSize;
    object = retainer;
  }
}

bool _isRetainer(AdaptedHeapObject object) {
  if (object.heapClass.isWeakEntry) return false;
  return object.references.isNotEmpty;
}

/// Verifies heap integrity rules.
///
/// 1. Nullness of 'retainedSize' and 'retainer' should be equal.
///
/// 2. Root's 'retainedSize' should be sum of shallow sizes of all reachable
/// objects.
void _verifyHeapIntegrity(AdaptedHeapData heap) {
  assert(() {
    var totalReachableSize = 0;

    for (var object in heap.objects) {
      assert(
        (object.retainedSize == null) == (object.retainer == null),
        'retainedSize = ${object.retainedSize}, retainer = ${object.retainer}',
      );
      if (object.retainer != null) totalReachableSize += object.shallowSize;
    }

    assert(
      heap.root.retainedSize == totalReachableSize,
      '${heap.root.retainedSize} not equal to $totalReachableSize',
    );
    return true;
  }());
}
