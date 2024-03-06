// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/utils.dart';
import 'class_name.dart';
import 'simple_items.dart';
import 'classes.dart';
import 'retainers.dart';

/// Value for rootIndex is taken from the doc:
/// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
const int heapRootIndex = 1;

@immutable
class HeapData {
  const HeapData._(
    this.graph,
    this.classes,
    this.footprint, {
    required this.created,
    required this.retainedSizes,
  });

  final HeapSnapshotGraph graph;

  final ClassDataList<SingleClassData>? classes;

  final MemoryFootprint? footprint;

  final List<int>? retainedSizes;

  final DateTime created;

  /// Returns the object with the given identityHashCode.
  ///
  /// It is full scan of the objects, so it is slow.
  /// But it is ok, because it is use only for eval.
  ///
  /// We do not pre-index hash codes to save memory.
  int? objectIndexByIdentityHashCode(int code) {
    final result = graph.objects.indexWhere((o) => o.identityHashCode == code);
    if (result == -1) return null;
    return result;
  }
}

final UiReleaser _uiReleaser = UiReleaser();

///
///
/// The flags may be not needed for the features,
/// but they may be needed to research how much CPU and memory
/// each part consumes.
Future<HeapData> calculateHeapData(
  HeapSnapshotGraph graph,
  DateTime created, {
  bool calculateRetainingPaths = true,
  bool calculateRetainedSizes = true,
  bool calculateClassData = true,
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
      graph.objects.length,
      heapRootIndex,
      weakClasses.isRetainer,
      (int index) => graph.objects[index].references,
      (int index) => graph.objects[index].shallowSize,
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
    int reachableSize = 0;

    for (var i = 0; i < graph.objects.length; i++) {
      if (_uiReleaser.step()) await _uiReleaser.releaseUi();
      final object = graph.objects[i];
      dartSize += object.shallowSize;

      // We do not show objects that will be garbage collected soon.
      // ignore: unnecessary_null_comparison, false positive
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
      final classStats = classes.putIfAbsent(
        className,
        () => SingleClassData(heapClass: className),
      );

      classStats.countInstance(graph, i, retainers, retainedSizes);
    }

    footprint = MemoryFootprint(dart: dartSize, reachable: reachableSize);
    classDataList = ClassDataList<SingleClassData>(classes.values.toList());

    // Check that retained size of root is the entire reachable heap.
    assert(
      retainedSizes == null ||
          retainedSizes[heapRootIndex] == footprint.reachable,
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
