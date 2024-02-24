// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../class_name.dart';
import 'classes.dart';

class HeapData {
  HeapData._(this.graph, {this.classes});

  /// Value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
  static const int rootIndex = 1;

  final HeapSnapshotGraph graph;

  List<SingleClassStats>? classes;
}

final UiReleaser _uiReleaser = UiReleaser();

///
///
/// The flags may be not needed for the features,
/// but they may be needed to research how much CPU and memory
/// each part consumes.
Future<HeapData> calculateHeapData(
  HeapSnapshotGraph graph, {
  bool calculateRetainingPaths = true,
  bool calculateRetainedSizes = true,
  bool calculateClassStatistics = true,
}) async {
  if (!calculateClassStatistics) return HeapData._(graph);

  Uint32List? retainers;
  final Uint32List? sizes =
      calculateRetainedSizes ? null : Uint32List(graph.objects.length);

  if (calculateRetainingPaths || calculateRetainedSizes) {
    final weakClasses = _WeakClasses(graph);

    retainers = Uint32List(graph.objects.length);
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

          if (weakClasses.isRetainer(child)) {
            nextCut.add(child);
          }
        }
      }
      if (nextCut.isEmpty) break;
      cut = nextCut;
    }
  }

  Map<HeapClassName, SingleClassStats>? classes;

  // Complexity of this part is O(n)*O(p) where
  // n is number of objects and p is length of retaining path.
  if (calculateClassStatistics) {
    classes = <HeapClassName, SingleClassStats>{};

    for (var i = 0; i < graph.objects.length; i++) {
      if (_uiReleaser.step()) await _uiReleaser.releaseUi();
      final object = graph.objects[i];
      final className =
          HeapClassName.fromHeapSnapshotClass(graph.classes[object.classId]);

      // We do not show objects that will be garbage collected soon.
      // ignore: unnecessary_null_comparison, false positive
      if (retainers != null && retainers[i] == 0) {
        continue;
      }

      // Verify assumption that all sentinel objects have zero size.
      // The code does not rely on it, it is just a check.
      assert(!className.isSentinel || object.shallowSize == 0);

      final classStats = classes.putIfAbsent(
        className,
        () => SingleClassStats(heapClass: className),
      );

      classStats.countInstance(graph, i, retainers, sizes);
    }
  }

  return HeapData._(graph, classes: classes?.values.toList());
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

class _WeakClasses {
  _WeakClasses(this.graph) {
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
        if (weakClassesToFind.isEmpty) return;
      }
    }
  }

  final HeapSnapshotGraph graph;

  /// Set of class ids that are not holding their references form garbage collection.
  late final _weakClasses = const <int>{};

  /// Returns true if the object is a retainer, where [objectIndex] is index in [graph].
  bool isRetainer(int objectIndex) {
    final object = graph.objects[objectIndex];
    if (object.references.isEmpty) return false;
    final classId = object.classId;
    if (_weakClasses.contains(classId)) return true;
    return false;
  }
}
