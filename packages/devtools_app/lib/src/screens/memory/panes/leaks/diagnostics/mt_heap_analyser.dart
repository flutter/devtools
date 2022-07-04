import 'package:flutter/material.dart';
import 'package:memory_tools/model.dart';

import '../model.dart';

void analyzeHeapAndSetRetainingPaths(
  MtHeap heap,
  List<LeakReport> notGCedLeaks,
) {
  if (!heap.isSpanningTreeBuilt) buildSpanningTree(heap);

  for (var l in notGCedLeaks) {
    l.retainingPath = heap.shortPath(l.theIdentityHashCode);
  }
}

void setDetailedPaths(MtHeap heap, List<LeakReport> notGCedLeaks) {
  assert(heap.isSpanningTreeBuilt);

  for (var l in notGCedLeaks) {
    l.detailedPath = heap.detailedPath(l.theIdentityHashCode);
  }
}

@visibleForTesting
void buildSpanningTree(MtHeap heap) {
  final root = heap.objects[MtHeap.rootIndex];
  root.parent = -1;

  // Array of all objects where the best distance from root is n.
  // n starts with 0 and increases by 1 on each step of the algorithm.
  var cut = [MtHeap.rootIndex];

  // On each step of algorithm we know that all nodes at distance n or closer to
  // root, has parent initialized.
  while (true) {
    final nextCut = <int>[];
    for (var p in cut) {
      final parent = heap.objects[p];
      for (var c in parent.references) {
        final child = heap.objects[c];

        if (child.parent != null) continue;
        if (_shouldSkip(child.klass)) continue;

        child.parent = p;
        parent.children.add(c);
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

bool _shouldSkip(String klass) {
  const toSkip = {
    '_WeakReferenceImpl',
    'FinalizerEntry',
    // 'DiagnosticsProperty',
    // '_ElementDiagnosticableTreeNode',
    // '_InspectorReferenceData',
    // 'DebugCreator',
    //'_WidgetTicker',
  };

  return toSkip.contains(klass);
}
