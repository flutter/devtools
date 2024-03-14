// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../shared/memory/adapted_heap_data.dart';
import '../../../../shared/memory/adapted_heap_object.dart';
import '../../../../shared/memory/class_name.dart';
import '../../../../shared/memory/retaining_path.dart';
import '../../../../shared/memory/simple_items.dart';
import '../../../../shared/primitives/utils.dart';
import 'class_filter.dart';
import 'model.dart';
import 'spanning_tree.dart';

class AdaptedHeap {
  AdaptedHeap._(this.data);

  static Future<AdaptedHeap> create(AdaptedHeapData data) async {
    final result = AdaptedHeap._(data);
    await result._initialize();
    return result;
  }

  final AdaptedHeapData data;

  late final MemoryFootprint footprint;

  SingleHeapClasses get classes => _classes;
  late final SingleHeapClasses _classes;

  Future<void> _initialize() async {
    if (!data.allFieldsCalculated) await calculateHeap(data);
    footprint = await _footprint(data);
    _classes = await _heapStatistics();
  }

  static Future<MemoryFootprint> _footprint(AdaptedHeapData data) async {
    return MemoryFootprint(
      dart: data.totalDartSize,
      reachable: data.totalReachableSize,
    );
  }

  final _uiReleaser = UiReleaser();

  Future<SingleHeapClasses> _heapStatistics() async {
    assert(data.allFieldsCalculated);

    final result = <HeapClassName, SingleClassStats>{};
    for (var i in Iterable<int>.generate(data.objects.length)) {
      if (_uiReleaser.step()) await _uiReleaser.releaseUi();
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

abstract class HeapClasses<T extends ClassData> with Sealable {
  List<T> get classStatsList;
}

mixin FilterableHeapClasses<T extends ClassData> on HeapClasses<T> {
  ClassFilter? _appliedFilter;
  List<T>? _filtered;

  List<T> filtered(ClassFilter newFilter, String? rootPackage) {
    _filtered = ClassFilter.filter(
      oldFilter: _appliedFilter,
      oldFiltered: _filtered,
      newFilter: newFilter,
      original: classStatsList,
      extractClass: (s) => s.heapClass,
      rootPackage: rootPackage,
    );
    _appliedFilter = newFilter;

    return _filtered!;
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

typedef StatsByPath = Map<PathFromRoot, ObjectSetStats>;
typedef StatsByPathEntry = MapEntry<PathFromRoot, ObjectSetStats>;

abstract class ClassData with Sealable {
  ClassData({required this.statsByPath, required this.heapClass});

  final StatsByPath statsByPath;
  late final List<StatsByPathEntry> statsByPathEntries = _getEntries();
  List<StatsByPathEntry> _getEntries() {
    assert(isSealed);
    return statsByPath.entries.toList(growable: false);
  }

  final HeapClassName heapClass;
}

/// Statistics for a class about a single heap.
class SingleClassStats extends ClassData {
  SingleClassStats({required super.heapClass})
      : objects = ObjectSet(),
        super(statsByPath: <PathFromRoot, ObjectSetStats>{});

  final ObjectSet objects;

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
      PathFromRoot(path),
      () => ObjectSet(),
    );
    objectsForPath.countInstance(object, excludeFromRetained: false);
  }
}
