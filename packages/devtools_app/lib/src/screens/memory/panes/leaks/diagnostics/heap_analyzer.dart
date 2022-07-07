// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../instrumentation/model.dart';
import 'model.dart';

/// Sets [retainingPath] to each [notGCedLeaks].
void analyzeHeapAndSetRetainingPaths(
  AdaptedHeap heap,
  List<LeakReport> notGCedLeaks,
) {
  if (!heap.isSpanningTreeBuilt) buildSpanningTree(heap);

  for (var l in notGCedLeaks) {
    l.retainingPath = heap.shortPath(l.code);
  }
}

/// Sets [detailedPath] to each leak.
void setDetailedPaths(AdaptedHeap heap, List<LeakReport> notGCedLeaks) {
  assert(heap.isSpanningTreeBuilt);

  for (var l in notGCedLeaks) {
    l.detailedPath = heap.detailedPath(l.code);
  }
}

/// Sets the field [retainer] for each object in the [heap], that has retaining
/// path to the root.
///
/// The algorithm takes O(number of references in the heap).
@visibleForTesting
void buildSpanningTree(AdaptedHeap heap) {
  final root = heap.objects[AdaptedHeap.rootIndex];
  root.retainer = -1;

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
        if (!_canRetain(child.klass)) continue;

        child.retainer = r;
        nextCut.add(c);
      }
    }
    if (nextCut.isEmpty) {
      heap.isSpanningTreeBuilt = true;
      return;
    }
    cut = nextCut;
  }
}

/// Detects if a class can retain an object from garbage collection.
bool _canRetain(String klass) {
  const toSkip = {
    '_WeakReferenceImpl',
    'FinalizerEntry',
  };

  return !toSkip.contains(klass);
}
