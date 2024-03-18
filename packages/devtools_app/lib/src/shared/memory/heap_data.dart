// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/utils.dart';
import 'class_name.dart';
import 'classes.dart';
import 'retainers.dart';
import 'simple_items.dart';

@immutable
class HeapData {
  HeapData._(
    this.graph,
    this.classes,
    this.footprint, {
    required this.created,
    required this.retainedSizes,
  });

  /// Value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
  static const int rootIndex = 1;

  final HeapSnapshotGraph graph;

  final ClassDataList<SingleClassData>? classes;

  final MemoryFootprint? footprint;

  final List<int>? retainedSizes;

  final DateTime created;

  /// Object index with the given identityHashCode.
  ///
  /// This field is calculated only for console evaluations
  late final Map<int, int> indexByCode = {
    for (var i = 0; i < graph.objects.length; i++)
      if (graph.objects[i].identityHashCode > 0)
        graph.objects[i].identityHashCode: i,
  };

  @visibleForTesting
  bool isReachable(int index) {
    return retainedSizes![index] > 0;
  }

  static final UiReleaser _uiReleaser = UiReleaser();

  /// Calculate the heap data from the given [graph].
  static Future<HeapData> calculate(
    HeapSnapshotGraph graph,
    DateTime created, {
    @visibleForTesting bool calculateRetainingPaths = true,
    @visibleForTesting bool calculateRetainedSizes = true,
    @visibleForTesting bool calculateClassData = true,
  }) async {
    if (!calculateClassData) {
      return HeapData._(
        graph,
        null,
        null,
        created: created,
        retainedSizes: null,
      );
    }

    List<int>? retainers;
    List<int>? retainedSizes;

    if (calculateRetainingPaths || calculateRetainedSizes) {
      final weakClasses = _WeakClasses(graph);

      final result = findShortestRetainers(
        graphSize: graph.objects.length,
        rootIndex: rootIndex,
        isWeak: weakClasses.isWeak,
        refs: (int index) => graph.objects[index].references,
        shallowSize: (int index) => graph.objects[index].shallowSize,
        calculateSizes: calculateRetainedSizes,
      );

      if (calculateRetainingPaths) retainers = result.retainers;
      if (calculateRetainedSizes) retainedSizes = result.retainedSizes;
    }

    ClassDataList<SingleClassData>? classDataList;
    MemoryFootprint? footprint;

    // Complexity of this part is O(n)*O(p) where
    // n is number of objects and p is length of retaining path.
    if (calculateClassData) {
      final classes = <HeapClassName, SingleClassData>{};
      int dartSize = 0;
      int reachableSize = graph.objects[rootIndex].shallowSize;

      for (var i = 0; i < graph.objects.length; i++) {
        if (_uiReleaser.step()) await _uiReleaser.releaseUi();
        final object = graph.objects[i];
        dartSize += object.shallowSize;

        // We do not show objects that will be garbage collected soon.
        if (retainers != null && retainers[i] == 0) {
          continue;
        }

        final className =
            HeapClassName.fromHeapSnapshotClass(graph.classes[object.classId]);

        // Ignore sentinels, because their size is not known.
        if (className.isSentinel) {
          assert(object.shallowSize == 0);
          continue;
        }

        reachableSize += object.shallowSize;
        final data = classes.putIfAbsent(
          className,
          () => SingleClassData(className: className),
        );

        data.countInstance(
          graph,
          index: i,
          retainers: retainers,
          retainedSizes: retainedSizes,
          heapRootIndex: rootIndex,
        );
      }

      footprint = MemoryFootprint(dart: dartSize, reachable: reachableSize);
      classDataList = ClassDataList<SingleClassData>(classes.values.toList());

      // Check that retained size of root is the entire reachable heap.
      assert(
        retainedSizes == null ||
            retainedSizes[rootIndex] == footprint.reachable,
      );
    }

    return HeapData._(
      graph,
      classDataList,
      footprint,
      created: created,
      retainedSizes: retainedSizes,
    );
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
  late final _weakClasses = <int>{};

  /// Returns true if the object cannot retain other objects.
  bool isWeak(int objectIndex) {
    final object = graph.objects[objectIndex];
    if (object.references.isEmpty) return true;
    final classId = object.classId;
    if (_weakClasses.contains(classId)) return true;
    return false;
  }
}
