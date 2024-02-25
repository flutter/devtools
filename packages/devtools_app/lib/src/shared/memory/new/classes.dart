// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../class_name.dart';
import 'retaining_path.dart';

/// Statistical size-information about objects.
class ObjectSetStats {
  static ObjectSetStats? subtract({
    required ObjectSetStats? subtract,
    required ObjectSetStats? from,
  }) {
    from ??= _empty;
    subtract ??= _empty;

    final result = ObjectSetStats()
      ..instanceCount = from.instanceCount - subtract.instanceCount
      ..shallowSize = from.shallowSize - subtract.shallowSize
      ..retainedSize = from.retainedSize - subtract.retainedSize;

    if (result.isZero) return null;
    return result;
  }

  static final _empty = ObjectSetStats();

  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  /// True if the object set is empty.
  ///
  /// When count is zero, size still can be non-zero, because size
  /// of added and size of removed items may be different.
  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(
    HeapSnapshotGraph graph,
    int index,
    List<int>? retainedSizes, {
    required bool excludeFromRetained,
  }) {
    if (!excludeFromRetained) {
      retainedSize += retainedSizes?[index] ?? 0;
    }
    shallowSize += graph.objects[index].shallowSize;
    instanceCount++;
  }

  void uncountInstance(
    HeapSnapshotGraph graph,
    int index,
    List<int>? retainedSizes, {
    required bool excludeFromRetained,
  }) {
    if (!excludeFromRetained) retainedSize -= retainedSizes?[index] ?? 0;
    shallowSize -= graph.objects[index].shallowSize;
    instanceCount--;
  }
}

/// Statistical and detailed size-information about objects.
class ObjectSet extends ObjectSetStats {
  static ObjectSet empty = ObjectSet();

  final objects = <int>[];

  /// Subset of objects that are excluded from the retained size
  /// calculation for this set.
  ///
  /// See [countInstance].
  final objectsExcludedFromRetainedSize = <int>{};

  @override
  bool get isZero => objects.isEmpty;

  @override
  void countInstance(
    HeapSnapshotGraph graph,
    int index,
    List<int>? retainedSizes, {
    required bool excludeFromRetained,
  }) {
    super.countInstance(
      graph,
      index,
      retainedSizes,
      excludeFromRetained: excludeFromRetained,
    );
    objects.add(index);
    if (excludeFromRetained) objectsExcludedFromRetainedSize.add(index);
  }

  @override
  void uncountInstance(
    HeapSnapshotGraph graph,
    int index,
    List<int>? retainedSizes, {
    required bool excludeFromRetained,
  }) {
    throw AssertionError('uncountInstance is not valid for $ObjectSet');
  }
}

class ClassDataList<T extends ClassData> {
  ClassDataList(this.list);

  final List<T> list;
}

abstract class ClassData {
  ClassData({required this.heapClass});

  final Map<PathFromRoot, ObjectSetStats> byPath = {};
  final HeapClassName heapClass;
}

class SingleClassData extends ClassData {
  SingleClassData({required super.heapClass});
  final ObjectSet objects = ObjectSet();

  void countInstance(
    HeapSnapshotGraph graph,
    int index,
    List<int>? retainers,
    List<int>? retainedSizes,
  ) {
    final PathFromRoot? path = retainers == null
        ? null
        : PathFromRoot.forObject(graph, retainers, index);

    final bool excludeFromRetained = path != null &&
        retainedSizes != null &&
        path.classes.contains(heapClass);

    objects.countInstance(
      graph,
      index,
      retainedSizes,
      excludeFromRetained: excludeFromRetained,
    );

    if (path != null) {
      byPath.putIfAbsent(
        path,
        () => ObjectSetStats(),
      );
      byPath[path]!.countInstance(
        graph,
        index,
        retainedSizes,
        excludeFromRetained: excludeFromRetained,
      );
    }
  }
}
