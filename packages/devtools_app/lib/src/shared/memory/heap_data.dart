// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/utils.dart';
import 'class_name.dart';
import 'classes.dart';
import 'retainers.dart';
import 'simple_items.dart';

/// Raw and calculated data of the heap snapshot.
class HeapData {
  HeapData(this.graph, {required this.created}) {
    unawaited(_calculate());
  }

  final HeapSnapshotGraph graph;

  final DateTime created;

  Future<void> get calculate => _calculated.future;
  final _calculated = Completer<void>();
  bool get isCalculated => _calculated.isCompleted;

  ClassDataList<SingleClassData>? classes;

  MemoryFootprint? footprint;

  List<int>? retainedSizes;

  /// Object index with the given identityHashCode.
  ///
  /// This field is calculated only for console evaluations.
  late final Map<int, int> indexByCode = {
    for (var i = 0; i < graph.objects.length; i++)
      if (graph.objects[i].identityHashCode > 0)
        graph.objects[i].identityHashCode: i,
  };

  @visibleForTesting
  bool isReachable(int index) {
    return retainedSizes![index] > 0;
  }

  static final _uiReleaser = UiReleaser();

  /// Calculate the heap data from the given [graph].
  Future<void> _calculate({
    @visibleForTesting bool calculateRetainingPaths = true,
    @visibleForTesting bool calculateRetainedSizes = true,
    @visibleForTesting bool calculateClassData = true,
  }) async {
    if (!calculateClassData) return;

    List<int>? retainers;

    if (calculateRetainingPaths || calculateRetainedSizes) {
      final weakClasses = _WeakClasses(graph);

      final result = findShortestRetainers(
        graphSize: graph.objects.length,
        rootIndex: heapRootIndex,
        isWeak: weakClasses.isWeak,
        refs: (int index) => graph.objects[index].references,
        shallowSize: (int index) => graph.objects[index].shallowSize,
        calculateSizes: calculateRetainedSizes,
      );

      if (calculateRetainingPaths) retainers = result.retainers;
      if (calculateRetainedSizes) retainedSizes = result.retainedSizes;
    }

    // Complexity of this part is O(n)*O(p) where
    // n is number of objects and p is length of retaining path.
    if (calculateClassData) {
      final nameToClass = <HeapClassName, SingleClassData>{};
      int dartSize = 0;
      int reachableSize = graph.objects[heapRootIndex].shallowSize;

      for (var i = 0; i < graph.objects.length; i++) {
        if (_uiReleaser.step()) await _uiReleaser.releaseUi();
        final object = graph.objects[i];
        dartSize += object.shallowSize;

        // We do not show unreachable objects, i.e. objects
        // that will be garbage collected soon.
        if (retainers?[i] == 0) {
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

        nameToClass
            .putIfAbsent(
              className,
              () => SingleClassData(className: className),
            )
            .countInstance(
              graph,
              index: i,
              retainers: retainers,
              retainedSizes: retainedSizes,
            );
      }

      footprint = MemoryFootprint(dart: dartSize, reachable: reachableSize);
      classes = ClassDataList<SingleClassData>(nameToClass.values.toList());

      // Check that retained size of root is the entire reachable heap.
      assert(
        retainedSizes == null ||
            retainedSizes![heapRootIndex] == footprint!.reachable,
      );
    }

    _calculated.complete();
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

  /// Set of class ids that are not holding their references from garbage collection.
  late final _weakClasses = <int>{};

  /// Returns true if the object cannot retain other objects.
  bool isWeak(int objectIndex) {
    final object = graph.objects[objectIndex];
    if (object.references.isEmpty) return true;
    final classId = object.classId;
    return _weakClasses.contains(classId);
  }
}
