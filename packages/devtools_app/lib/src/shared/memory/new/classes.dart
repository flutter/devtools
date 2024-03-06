// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../screens/memory/shared/heap/class_filter.dart';
import '../../primitives/utils.dart';
import '../class_name.dart';
import 'heap_data.dart';
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

@immutable
class ClassDataList<T extends ClassData> {
  ClassDataList(this._originalList)
      : _appliedFilter = null,
        _filtered = null;

  ClassDataList._filtered({
    required List<T> original,
    required ClassFilter appliedFilter,
    required List<T> filtered,
  })  : _originalList = original,
        _appliedFilter = appliedFilter,
        _filtered = filtered;

  List<T> get list => _filtered ?? _originalList;

  final List<T> _originalList;
  final ClassFilter? _appliedFilter;
  final List<T>? _filtered;

  Map<HeapClassName, T> asMap() =>
      {for (var c in _originalList) c.heapClass: c};

  ClassDataList<T> filtered(ClassFilter newFilter, String? rootPackage) {
    final filtered = ClassFilter.filter(
      oldFilter: _appliedFilter,
      oldFiltered: _filtered,
      newFilter: newFilter,
      original: _originalList,
      extractClass: (s) => s.heapClass,
      rootPackage: rootPackage,
    );
    return ClassDataList._filtered(
      original: _originalList,
      appliedFilter: newFilter,
      filtered: filtered,
    );
  }

  late final T withMaxRetainedSize = () {
    return list.reduce(
      (a, b) => a.objects.retainedSize > b.objects.retainedSize ? a : b,
    );
  }();
}

abstract class ClassData {
  ClassData({required this.heapClass});

  ObjectSetStats get objects;
  Map<PathFromRoot, ObjectSetStats> get byPath;

  final HeapClassName heapClass;

  late final PathFromRoot pathWithMaxRetainedSize = () {
    assert(byPath.isNotEmpty);
    return byPath.keys.reduce(
      (a, b) => byPath[a]!.retainedSize > byPath[b]!.retainedSize ? a : b,
    );
  }();
}

class SingleClassData extends ClassData {
  SingleClassData({required super.heapClass});

  @override
  final ObjectSet objects = ObjectSet();

  @override
  final Map<PathFromRoot, ObjectSetStats> byPath = {};

  void countInstance(
    HeapSnapshotGraph graph,
    int index,
    List<int>? retainers,
    List<int>? retainedSizes,
  ) {
    final PathFromRoot? path = retainers == null
        ? null
        : PathFromRoot.forObject(
            graph,
            shortestRetainers: retainers,
            objectId: index,
            heapRootIndex: heapRootIndex,
          );

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
