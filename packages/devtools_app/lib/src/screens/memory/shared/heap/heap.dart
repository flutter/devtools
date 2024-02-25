// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../shared/memory/adapted_heap_data.dart';
import '../../../../shared/memory/adapted_heap_object.dart';
import '../../../../shared/memory/class_name.dart';
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

    final result = <HeapClassName, SingleClassStats_>{};
    for (var i in Iterable<int>.generate(data.objects.length)) {
      if (_uiReleaser.step()) await _uiReleaser.releaseUi();
      final object = data.objects[i];
      final className = object.heapClass;

      // We do not show objects that will be garbage collected soon or are
      // native.
      if (object.retainedSize == null || className.isSentinel) continue;

      final singleHeapClass = result.putIfAbsent(
        className,
        () => SingleClassStats_(heapClass: className),
      );
      singleHeapClass.countInstance(data, i);
    }

    return SingleHeapClasses(result)..seal();
  }
}

abstract class HeapClasses_<T extends ClassStats_> with Sealable {
  List<T> get classStatsList;
}

mixin FilterableHeapClasses_<T extends ClassStats_> on HeapClasses_<T> {
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
class SingleHeapClasses extends HeapClasses_<SingleClassStats_>
    with FilterableHeapClasses_<SingleClassStats_> {
  SingleHeapClasses(this.classesByName);

  /// Maps full class name to class.
  final Map<HeapClassName, SingleClassStats_> classesByName;
  late final List<SingleClassStats_> classes =
      classesByName.values.toList(growable: false);

  @override
  void seal() {
    super.seal();
    for (var stats in classes) {
      stats.seal();
    }
  }

  @override
  List<SingleClassStats_> get classStatsList => classes;
}

typedef StatsByPath = Map<ClassOnlyHeapPath, ObjectSetStats_>;
typedef StatsByPathEntry = MapEntry<ClassOnlyHeapPath, ObjectSetStats_>;

abstract class ClassStats_ with Sealable {
  ClassStats_({required this.statsByPath, required this.heapClass});

  final StatsByPath statsByPath;
  late final List<StatsByPathEntry> statsByPathEntries = _getEntries();
  List<StatsByPathEntry> _getEntries() {
    assert(isSealed);
    return statsByPath.entries.toList(growable: false);
  }

  final HeapClassName heapClass;
}

/// Statistics for a class about a single heap.
class SingleClassStats_ extends ClassStats_ {
  SingleClassStats_({required super.heapClass})
      : objects = ObjectSet_(),
        super(statsByPath: <ClassOnlyHeapPath, ObjectSetStats_>{});

  final ObjectSet_ objects;

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
      () => ObjectSet_(),
    );
    objectsForPath.countInstance(object, excludeFromRetained: false);
  }
}

/// Statistical size-information about objects.
class ObjectSetStats_ with Sealable {
  static ObjectSetStats_? subtract({
    required ObjectSetStats_? subtract,
    required ObjectSetStats_? from,
  }) {
    from ??= _empty;
    subtract ??= _empty;

    final result = ObjectSetStats_()
      ..instanceCount = from.instanceCount - subtract.instanceCount
      ..shallowSize = from.shallowSize - subtract.shallowSize
      ..retainedSize = from.retainedSize - subtract.retainedSize;

    if (result.isZero) return null;
    return result;
  }

  static final _empty = ObjectSetStats_()..seal();

  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(
    MockAdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    assert(!isSealed);
    if (!excludeFromRetained) retainedSize += object.retainedSize!;
    shallowSize += object.shallowSize;
    instanceCount++;
  }

  void uncountInstance(
    MockAdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    assert(!isSealed);
    if (!excludeFromRetained) retainedSize -= object.retainedSize!;
    shallowSize -= object.shallowSize;
    instanceCount--;
  }
}

/// Statistical and detailed size-information about objects.
class ObjectSet_ extends ObjectSetStats_ {
  static ObjectSet_ empty = ObjectSet_()..seal();

  final objectsByCodes = <IdentityHashCode, MockAdaptedHeapObject>{};

  /// Subset of objects that are excluded from the retained size
  /// calculation for this set.
  ///
  /// See [countInstance].
  final objectsExcludedFromRetainedSize = <IdentityHashCode>{};

  @override
  bool get isZero => objectsByCodes.isEmpty;

  @override
  void countInstance(
    MockAdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    if (objectsByCodes.containsKey(object.code)) return;
    super.countInstance(object, excludeFromRetained: excludeFromRetained);
    objectsByCodes[object.code] = object;
    if (excludeFromRetained) objectsExcludedFromRetainedSize.add(object.code);
  }

  @override
  void uncountInstance(
    MockAdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    throw AssertionError('uncountInstance is not valid for $ObjectSet_');
  }
}
