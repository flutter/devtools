// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../shared/memory/class_name.dart';
import 'class_filter.dart';
import 'model.dart';
import 'spanning_tree.dart';

class AdaptedHeap {
  AdaptedHeap(this.data);

  final AdaptedHeapData data;

  late final SingleHeapClasses classes = _heapStatistics();

  SingleHeapClasses _heapStatistics() {
    final result = <HeapClassName, SingleClassStats>{};
    if (!data.isSpanningTreeBuilt) buildSpanningTree(data);

    for (var i in Iterable.generate(data.objects.length)) {
      final object = data.objects[i];
      final className = object.heapClass;

      // We do not show objects that will be garbage collected soon or are
      // native.
      if (object.retainedSize == null || className.isSentinel) continue;

      final singleHeapClass = result.putIfAbsent(
        className,
        () => SingleClassStats(heapClass: className),
      );
      singleHeapClass.countInstance(data, i);
    }

    return SingleHeapClasses(result)..seal();
  }
}

abstract class HeapClasses<T extends ClassStats> with Sealable {
  List<T> get classStatsList;
}

mixin FilterableHeapClasses<T extends ClassStats> on HeapClasses<T> {
  ClassFilter? _appliedFilter;
  List<T>? _filtered;

  List<T> filtered(ClassFilter newFilter, String? rootPackage) {
    final oldFilter = _appliedFilter;
    final oldFiltered = _filtered;
    _appliedFilter = newFilter;
    if ((oldFilter == null) != (oldFiltered == null)) {
      throw StateError('Nullness should match.');
    }

    // Return previous data if filter did not change.
    if (oldFilter == newFilter) return oldFiltered!;

    // Return previous data if filter is identical.
    final task = newFilter.task(previous: oldFilter);
    if (task == FilteringTask.doNothing) return oldFiltered!;

    final Iterable<T> dataToFilter;
    if (task == FilteringTask.refilter) {
      dataToFilter = classStatsList;
    } else if (task == FilteringTask.reuse) {
      dataToFilter = oldFiltered!;
    } else {
      throw StateError('Unexpected task: $task.');
    }

    final result = dataToFilter
        .where((e) => newFilter.apply(e.heapClass, rootPackage))
        .toList();
    return _filtered = result;
  }
}

/// Set of heap class statistical information for single heap (not comparison between two heaps).
class SingleHeapClasses extends HeapClasses<SingleClassStats>
    with FilterableHeapClasses<SingleClassStats> {
  SingleHeapClasses(this.classesByName);

  /// Maps full class name to class.
  final Map<HeapClassName, SingleClassStats> classesByName;
  late final List<SingleClassStats> classes =
      classesByName.values.toList(growable: false);

  @override
  void seal() {
    super.seal();
    for (var stats in classes) {
      stats.seal();
    }
  }

  @override
  List<SingleClassStats> get classStatsList => classes;
}

typedef StatsByPath = Map<ClassOnlyHeapPath, ObjectSetStats>;
typedef StatsByPathEntry = MapEntry<ClassOnlyHeapPath, ObjectSetStats>;

abstract class ClassStats with Sealable {
  ClassStats({required this.statsByPath, required this.heapClass});

  final StatsByPath statsByPath;
  late final List<StatsByPathEntry> statsByPathEntries = _getEntries();
  List<StatsByPathEntry> _getEntries() {
    assert(isSealed);
    return statsByPath.entries.toList(growable: false);
  }

  final HeapClassName heapClass;
}

/// Statistics for a class about a single heap.
class SingleClassStats extends ClassStats {
  SingleClassStats({required super.heapClass})
      : objects = ObjectSet(),
        super(statsByPath: <ClassOnlyHeapPath, ObjectSetStats>{});

  final ObjectSet objects;

  late final entries = statsByPath.entries.toList(growable: false);

  void countInstance(AdaptedHeapData data, int objectIndex) {
    assert(!isSealed);
    final object = data.objects[objectIndex];
    assert(object.heapClass.fullName == heapClass.fullName);

    final path = data.retainingPath(objectIndex);
    objects.countInstance(
      object,
      excludeFromRetained: path?.isRetainedBySameClass ?? false,
    );

    if (path == null) return;
    final objectsForPath = statsByPath.putIfAbsent(
      ClassOnlyHeapPath(path),
      () => ObjectSet(),
    );
    objectsForPath.countInstance(object, excludeFromRetained: false);
  }

  bool get isZero => objects.isZero;
}

/// Statistical size-information about objects.
class ObjectSetStats with Sealable {
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

  static final _empty = ObjectSetStats()..seal();

  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    assert(!isSealed);
    if (!excludeFromRetained) retainedSize += object.retainedSize!;
    shallowSize += object.shallowSize;
    instanceCount++;
  }

  void uncountInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    assert(!isSealed);
    if (!excludeFromRetained) retainedSize -= object.retainedSize!;
    shallowSize -= object.shallowSize;
    instanceCount--;
  }
}

/// Statistical and detailed size-information about objects.
class ObjectSet extends ObjectSetStats {
  static ObjectSet empty = ObjectSet()..seal();

  final objectsByCodes = <IdentityHashCode, AdaptedHeapObject>{};
  final notCountedInRetained = <IdentityHashCode>{};

  @override
  bool get isZero => objectsByCodes.isEmpty;

  @override
  void countInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    if (objectsByCodes.containsKey(object.code)) return;
    super.countInstance(object, excludeFromRetained: excludeFromRetained);
    objectsByCodes[object.code] = object;
    if (excludeFromRetained) notCountedInRetained.add(object.code);
  }

  @override
  void uncountInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    throw AssertionError('uncountInstance is not valid for $ObjectSet');
  }
}
