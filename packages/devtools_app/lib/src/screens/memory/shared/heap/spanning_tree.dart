// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../shared/memory/adapted_heap_data.dart';
import '../../../../shared/memory/adapted_heap_object.dart';
import '../../../../shared/primitives/utils.dart';

final _uiReleaser = UiReleaser();

/// Performs calculations on the [heap] to populate fields.
///
/// * Sets the field retainer and retainedSize for each object in the [heap], that
/// has retaining path to the root.
/// * Populates [MockAdaptedHeapObject.inRefs].
/// * Sets [MockAdaptedHeapObject.totalDartSize].
/// * Sets [AdaptedHeapData.allFieldsCalculated] to true.
Future<void> calculateHeap(AdaptedHeapData heap) async {
  assert(!heap.allFieldsCalculated);
  await _setRetainers(heap);
  await _setInboundRefs(heap);
  heap.allFieldsCalculated = true;
  _verifyHeapIntegrity(heap);
}

Future<void> _setInboundRefs(AdaptedHeapData heap) async {
  int totalDartSize = 0;
  for (final from in Iterable<int>.generate(heap.objects.length)) {
    totalDartSize += heap.objects[from].shallowSize;
    if (_uiReleaser.step()) await _uiReleaser.releaseUi();
    for (final to in heap.objects[from].outRefs) {
      assert(from != to);
      heap.objects[to].inRefs.add(from);
    }
  }
  heap.totalDartSize = totalDartSize;
}

/// The algorithm takes O(number of references in the heap).
Future<void> _setRetainers(AdaptedHeapData heap) async {
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
    if (_uiReleaser.step()) await _uiReleaser.releaseUi();
    final nextCut = <int>[];
    for (var r in cut) {
      final retainer = heap.objects[r];
      for (var c in retainer.outRefs) {
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
void _propagateSize(MockAdaptedHeapObject object, AdaptedHeapData heap) {
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

bool _isRetainer(MockAdaptedHeapObject object) {
  if (object.heapClass.isWeakEntry) return false;
  return object.outRefs.isNotEmpty;
}

/// Verifies heap integrity rules.
///
/// 1. Nullness of 'retainedSize' and 'retainer' should be equal.
///
/// 2. Root's 'retainedSize' should be sum of shallow sizes of all reachable
/// objects.
///
/// 3. All inRefs don't contain duplicates.
void _verifyHeapIntegrity(AdaptedHeapData heap) {
  assert(() {
    var totalReachableSize = 0;
    var totalInRefs = 0;
    var totalOutRefs = 0;

    for (final int i in Iterable.generate(heap.objects.length)) {
      final object = heap.objects[i];
      assert(
        (object.retainedSize == null) == (object.retainer == null),
        'retainedSize = ${object.retainedSize}, retainer = ${object.retainer}',
      );
      if (object.retainer != null) totalReachableSize += object.shallowSize;

      assert(!object.inRefs.contains(i));
      assert(!object.outRefs.contains(i));

      totalInRefs += object.inRefs.length;
      totalOutRefs += object.outRefs.length;
    }

    assert(totalInRefs == totalOutRefs, 'Error in inRefs calculation.');

    assert(
      heap.root.retainedSize == totalReachableSize,
      '${heap.root.retainedSize} not equal to $totalReachableSize',
    );
    return true;
  }());
}
