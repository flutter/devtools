// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';

/// Sets the field retainer and retainedSize for each object in the [heap], that
/// has retaining path to the root.
void buildSpanningTree(AdaptedHeap heap) {
  _setRetainers(heap);
  heap.isSpanningTreeBuilt = true;
}

/// The algorithm takes O(number of references in the heap).
void _setRetainers(AdaptedHeap heap) {
  heap.objects[AdaptedHeap.rootIndex].retainer = -1;

  // Array of all objects where the best distance from root is n.
  // n starts with 0 and increases by 1 on each step of the algorithm.
  // The objects are ends of the graph cut.
  // See description of cut:
  // https://en.wikipedia.org/wiki/Cut_(graph_theory)
  // On each step the algorithm moves the cut one step further from the root.
  var cut = [AdaptedHeap.rootIndex];

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
        if (child.references.isEmpty) _processLeafSize(child, heap);
        if (!_canRetain(child.klass, child.library)) continue;
        nextCut.add(c);
      }
    }
    if (nextCut.isEmpty) return;
    cut = nextCut;
  }
}

/// Assuming the [object] is leaf, initializes its retained size
/// and adds the size to all its retainers.
void _processLeafSize(AdaptedHeapObject object, AdaptedHeap heap) {
  assert(object.retainer != null);
  final addedSize = object.shallowSize;

  object.retainedSize = addedSize;
  while (object.retainer != -1) {
    final retainer = heap.objects[object.retainer!];
    assert(retainer.retainer != null);
    assert(retainer != object);
    retainer.retainedSize = retainer.retainedSize ?? 0 + addedSize;
    object = retainer;
  }
}

/// Detects if a class can retain an object from garbage collection.
bool _canRetain(String klass, String library) {
  // Classes that hold reference to an object without preventing
  // its collection.
  const weakHolders = {
    '_WeakProperty': 'dart.core',
    '_WeakReferenceImpl': 'dart.core',
    'FinalizerEntry': 'dart._internal',
  };

  if (!weakHolders.containsKey(klass)) return true;
  if (weakHolders[klass] == library) return false;

  // If a class lives in unexpected library, this can be because of
  // (1) name collision or (2) bug in this code.
  // Throwing exception in debug mode to verify option #2.
  // TODO(polina-c): create a way for users to add their weak classes
  // or detect weak references automatically, without hard coding
  // class names.
  assert(false, 'Unexpected library for $klass: $library.');
  return true;
}
