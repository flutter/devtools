// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';
import 'spanning_tree.dart';

class AdaptedHeap {
  AdaptedHeap(this.data);

  final AdaptedHeapData data;

  late final SingleHeapClasses classes = _heapStatistics(data);

  static SingleHeapClasses _heapStatistics(AdaptedHeapData data) {
    final result = <HeapClassName, SingleClassStats>{};
    if (!data.isSpanningTreeBuilt) buildSpanningTree(data);

    for (var i in Iterable.generate(data.objects.length)) {
      final object = data.objects[i];
      final className = object.heapClass;

      // We do not show objects that will be garbage collected soon or are
      // native.
      if (object.retainedSize == null || className.isSentinel) continue;

      final singleHeapClass =
          result.putIfAbsent(className, () => SingleClassStats(className));
      singleHeapClass.countInstance(data, i);
    }

    return SingleHeapClasses(result)..seal();
  }
}

abstract class HeapClasses with Sealable {
  // HeapClass? classByName(HeapClassName? name);
}

class SingleHeapClasses extends HeapClasses {
  SingleHeapClasses(this.classesByName);

  /// Maps full class name to class.
  final Map<HeapClassName, SingleClassStats> classesByName;
  late final List<SingleClassStats> classes =
      classesByName.values.toList(growable: false);

  @override
  void seal() {
    super.seal();
    for (var analysis in classes) {
      analysis.seal();
    }
  }
}

typedef StatsByPath = Map<ClassOnlyHeapPath, ObjectSetStats>;
typedef StatsByPathEntry = MapEntry<ClassOnlyHeapPath, ObjectSetStats>;

abstract class ClassStats with Sealable {
  ClassStats(this.statsByPath);

  final StatsByPath statsByPath;
  late final List<StatsByPathEntry> statsByPathEntries = _getEntries();
  List<StatsByPathEntry> _getEntries() {
    assert(isSealed);
    return statsByPath.entries.toList(growable: false);
  }
}

class SingleClassStats extends ClassStats {
  SingleClassStats(this.heapClass)
      : objects = ObjectSet(),
        super(<ClassOnlyHeapPath, ObjectSetStats>{});

  final HeapClassName heapClass;
  final ObjectSet objects;

  late final entries = statsByPath.entries.toList(growable: false);

  void countInstance(AdaptedHeapData data, int objectIndex) {
    assert(!isSealed);
    final object = data.objects[objectIndex];
    assert(object.heapClass.fullName == heapClass.fullName);
    objects.countInstance(object);

    final path = data.retainingPath(objectIndex);
    if (path == null) return;
    final objectsForPath = statsByPath.putIfAbsent(
      ClassOnlyHeapPath(path),
      () => ObjectSet(),
    );
    objectsForPath.countInstance(object);
  }

  bool get isZero => objects.isZero;
}

/// Size of set of instances.
class ObjectSetStats with Sealable {
  ObjectSetStats();

  static ObjectSetStats? subtruct({
    required ObjectSetStats? minuend,
    required ObjectSetStats? subtrahend,
  }) {
    minuend ??= _empty;
    subtrahend ??= _empty;

    final result = ObjectSetStats()
      ..instanceCount = minuend.instanceCount - subtrahend.instanceCount
      ..shallowSize = minuend.shallowSize - subtrahend.shallowSize
      ..retainedSize = minuend.retainedSize - subtrahend.retainedSize;

    if (result.isZero) return null;
    return result;
  }

  static final ObjectSetStats _empty = ObjectSetStats()..seal();

  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(AdaptedHeapObject object) {
    assert(!isSealed);
    retainedSize += object.retainedSize!;
    shallowSize += object.shallowSize;
    instanceCount++;
  }

  void uncountInstance(AdaptedHeapObject object) {
    assert(!isSealed);
    retainedSize -= object.retainedSize!;
    shallowSize -= object.shallowSize;
    instanceCount--;
  }
}

/// Size of set of instances.
class ObjectSet extends ObjectSetStats {
  ObjectSet();

  static ObjectSet empty = ObjectSet()..seal();

  final objectsByCodes = <IdentityHashCode, AdaptedHeapObject>{};

  @override
  bool get isZero => objectsByCodes.isEmpty;

  @override
  void countInstance(AdaptedHeapObject object) {
    if (objectsByCodes.containsKey(object.code)) return;
    super.countInstance(object);
    objectsByCodes[object.code] = object;
  }

  @override
  void uncountInstance(AdaptedHeapObject object) {
    throw AssertionError('uncountInstance is not valid for $ObjectSet');
  }
}
