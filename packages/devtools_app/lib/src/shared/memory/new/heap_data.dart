// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';

import '../../../screens/memory/shared/heap/heap.dart';
import '../../primitives/utils.dart';

class HeapData {
  HeapData._(
    this.graph, {
    this.shortestRetainers,
    this.retainedSizes,
    this.classStats,
  });

  /// Value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
  static const int rootIndex = 1;

  final HeapSnapshotGraph graph;

  /// Each cell contains index of referrer for shortest retaining path from the root to the object.
  ///
  /// If 0, there is no retaining path from root.
  final Uint32List? shortestRetainers;

  final Uint32List? retainedSizes;

  final SingleClassStats? classStats;
}

final UiReleaser _uiReleaser = UiReleaser();

Future<HeapData> calculateHeapData(
  HeapSnapshotGraph graph, {
  bool shortestRetainers = true,
  bool retainedSizes = true,
  bool classStatistics = true,
}) async {
  if (!shortestRetainers && !retainedSizes) {
    return HeapData._(graph);
  }

  final classes = _Classes(
    graph,
    calculateClassStats: classStatistics,
    calculateWeakClasses: shortestRetainers || retainedSizes,
  );

  final Uint32List retainers = Uint32List(graph.objects.length);
  final Uint32List? sizes =
      retainedSizes ? null : Uint32List(graph.objects.length);
  sizes?[HeapData.rootIndex] = graph.objects[HeapData.rootIndex].shallowSize;

  // Array of all objects where the best distance from root is n.
  // n starts with 0 and increases by 1 on each step of the algorithm.
  // The objects are ends of the graph cut.
  // See description of cut:
  // https://en.wikipedia.org/wiki/Cut_(graph_theory)
  // On each step the algorithm moves the cut one step further from the root.
  var cut = [HeapData.rootIndex];

  // On each step of algorithm we know that all nodes at distance n or closer to
  // root, has parent initialized.
  while (true) {
    if (_uiReleaser.step()) await _uiReleaser.releaseUi();
    final nextCut = <int>[];
    for (var r in cut) {
      final retainer = graph.objects[r];
      for (var child in retainer.references) {
        if (retainers[child] > 0) continue;
        retainers[child] = r;

        if (sizes != null) _propagateSize(graph, sizes, retainers, child);

        if (classes.isRetainer(child)) {
          nextCut.add(child);
        }
      }
    }
    if (nextCut.isEmpty) {
      return HeapData._(
        graph,
        shortestRetainers: shortestRetainers ? retainers : null,
        retainedSizes: sizes,
      );
    }
    cut = nextCut;
  }
}

/// Assuming the object is leaf, initializes its retained size
/// and adds the size to each shortest retainer.
void _propagateSize(
  HeapSnapshotGraph graph,
  Uint32List sizes,
  Uint32List retainers,
  int index,
) {
  final addedSize = graph.objects[index].shallowSize;
  sizes[index] = addedSize;

  while (retainers[index] > 0) {
    index = retainers[index];
    sizes[index] += addedSize;
  }
}

class _Classes {
  _Classes(
    this.graph, {
    required bool calculateWeakClasses,
    required bool calculateClassStats,
  }) {
    final weakClassesToFind = <String, String>{
      '_WeakProperty': 'dart:core',
      '_WeakReferenceImpl': 'dart:core',
      'FinalizerEntry': 'dart:_internal',
    };

    for (final theClass in graph.classes) {
      if (weakClassesToFind.containsKey(theClass.name) &&
          weakClassesToFind[theClass.name] == theClass.libraryName) {
        _weakClasses.add(theClass.classId);
        weakClassesToFind.remove(theClass.name);
        if (weakClassesToFind.isEmpty) {
          break;
        }
      }
    }
  }

  final HeapSnapshotGraph graph;

  final _weakClasses = <int>{};

  final ClassStats? classStats = null;

  bool isRetainer(int objectIndex) {
    final object = graph.objects[objectIndex];
    if (object.references.isEmpty) return false;
    final classId = object.classId;
    if (_weakClasses.contains(classId)) return true;
    return false;
  }
}
