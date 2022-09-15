// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

import 'model.dart';

/// Sets the field retainer and retainedSize for each object in the [heap], that
/// has retaining path to the root.
void buildSpanningTree(AdaptedHeap heap) {
  assert(!heap.isSpanningTreeBuilt);
  _setRetainers(heap);
  heap.isSpanningTreeBuilt = true;
  assert(_verifyHeapIntegrity(heap));
}

/// The algorithm takes O(number of references in the heap).
void _setRetainers(AdaptedHeap heap) {
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
void _propagateSize(AdaptedHeapObject object, AdaptedHeap heap) {
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
  if (isWeakEntry(object.className, object.library)) return false;
  return object.references.isNotEmpty;
}

/// Detects if a class can retain an object from garbage collection.
@visibleForTesting
bool isWeakEntry(String klass, String library) {
  // Classes that hold reference to an object without preventing
  // its collection.
  const weakHolders = {
    '_WeakProperty': 'dart.core',
    '_WeakReferenceImpl': 'dart.core',
    'FinalizerEntry': 'dart._internal',
  };

  if (!weakHolders.containsKey(klass)) return false;
  if (weakHolders[klass] == library) return true;

  // If a class lives in unexpected library, this can be because of
  // (1) name collision or (2) bug in this code.
  // Throwing exception in debug mode to verify option #2.
  // TODO(polina-c): create a way for users to add their weak classes
  // or detect weak references automatically, without hard coding
  // class names.
  assert(false, 'Unexpected library for $klass: $library.');
  return false;
}

/// Verifies heap integrity rules.
///
/// 1. Nullness of 'retainedSize' and 'retainer' should be equal.
///
/// 2. Root's 'retainedSize' should be sum of shallow sizes of all reachable
/// objects.
bool _verifyHeapIntegrity(AdaptedHeap heap) {
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
}
