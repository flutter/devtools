// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';
import 'spanning_tree.dart';

class AdaptedHeap {
  AdaptedHeap(this.data);

  final AdaptedHeapData data;

  late final SingeHeapClasses classes = _heapStatistics(data);

  static SingeHeapClasses _heapStatistics(AdaptedHeapData data) {
    final result = <HeapClassName, SingleHeapClass>{};
    if (!data.isSpanningTreeBuilt) buildSpanningTree(data);

    for (var i in Iterable.generate(data.objects.length)) {
      final object = data.objects[i];
      final className = object.heapClass;

      // We do not show objects that will be garbage collected soon or are
      // native.
      if (object.retainedSize == null || className.isSentinel) continue;

      final singleHeapClass =
          result.putIfAbsent(className, () => SingleHeapClass(className));
      singleHeapClass.countInstance(data, i);
    }

    return SingeHeapClasses(result)..seal();
  }
}

abstract class HeapClasses with Sealable {
  // HeapClass? classByName(HeapClassName? name);
}

class SingeHeapClasses extends HeapClasses {
  SingeHeapClasses(this.classesByName);

  /// Maps full class name to class.
  final Map<HeapClassName, SingleHeapClass> classesByName;
  late final List<SingleHeapClass> classes =
      classesByName.values.toList(growable: false);

  @override
  void seal() {
    super.seal();
    for (var analysis in classes) {
      analysis.seal();
    }
  }
}

typedef ObjectsByPath = Map<ClassOnlyHeapPath, ObjectSetStats>;

abstract class HeapClass with Sealable {}

class SingleHeapClass extends HeapClass {
  SingleHeapClass(this.heapClass)
      : objects = ObjectSet(),
        objectsByPath = <ClassOnlyHeapPath, ObjectSetStats>{};

  // HeapClassStatistics.negative(HeapClassStatistics other)
  //     : heapClass = other.heapClass,
  //       total = ObjectSet.negative(other.total),
  //       objectsByPath = other.objectsByPath
  //           .map((key, value) => MapEntry(key, ObjectSet.negative(value))) {
  //   seal();
  // }

  // HeapClassStatistics.subtract(
  //   HeapClassStatistics minuend,
  //   HeapClassStatistics subtrahend,
  // )   : assert(minuend.heapClass.fullName == subtrahend.heapClass.fullName),
  //       heapClass = minuend.heapClass,
  //       total = ObjectSet.subtract(minuend.total, subtrahend.total),
  //       objectsByPath = _subtractSizesByPath(
  //           minuend.objectsByPath, subtrahend.objectsByPath) {
  //   seal();
  // }

  // static ObjectsByPath _subtractSizesByPath(
  //   ObjectsByPath minuend,
  //   ObjectsByPath subtrahend,
  // ) =>
  //     subtractMaps<ClassOnlyHeapPath, ObjectSet>(
  //       minuend: minuend,
  //       subtrahend: subtrahend,
  //       subtract: (minuend, subtrahend) {
  //         final diff = ObjectSet.subtract(minuend, subtrahend);
  //         if (diff.isZero) return null;
  //         return diff;
  //       },
  //       negate: (value) => ObjectSet.negative(value),
  //     );

  final HeapClassName heapClass;
  final ObjectSet objects;
  final ObjectsByPath objectsByPath;

  void countInstance(AdaptedHeapData data, int objectIndex) {
    assert(!isSealed);
    final object = data.objects[objectIndex];
    assert(object.heapClass.fullName == heapClass.fullName);
    objects.countInstance(object);

    final path = data.retainingPath(objectIndex);
    if (path == null) return;
    final objectsForPath = objectsByPath.putIfAbsent(
      ClassOnlyHeapPath(path),
      () => ObjectSet(),
    );
    objectsForPath.countInstance(object);
  }

  bool get isZero => objects.isZero;
}

class ObjectSetDiff {
  ObjectSetDiff(ObjectSet before, ObjectSet after) {
    final objects = before.objects.union(after.objects);
    for (var object in objects) {
      if (before.objects.contains(object) && (after.objects.contains(object)))
        continue;

      if (before.objects.contains(object)) {
        deleted.countInstance(object);
        delta.uncountInstance(object);
      }
      if (after.objects.contains(object)) {
        created.countInstance(object);
        delta.countInstance(object);
      }
      assert(false);
    }
    created.seal();
    deleted.seal();
    delta.seal();
  }

  final created = ObjectSet();
  final deleted = ObjectSet();
  final delta = ObjectSetStats();
}

/// Size of set of instances.
class ObjectSetStats with Sealable {
  ObjectSetStats();

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

  // ObjectSet.negative(ObjectSet other)
  //     : instanceCount = -other.instanceCount,
  //       shallowSize = -other.shallowSize,
  //       retainedSize = -other.retainedSize {
  //   seal();
  // }

  // ObjectSet.subtract(ObjectSet left, ObjectSet right)
  //     : instanceCount = left.instanceCount - right.instanceCount,
  //       shallowSize = left.shallowSize - right.shallowSize,
  //       retainedSize = left.retainedSize - right.retainedSize {
  //   seal();
  // }

  final objects = <AdaptedHeapObject>{};

  @override
  bool get isZero => objects.isEmpty;

  @override
  void countInstance(AdaptedHeapObject object) {
    assert(!objects.contains(object));
    super.countInstance(object);
    objects.add(object);
  }

  @override
  void uncountInstance(AdaptedHeapObject object) {
    throw AssertionError('uncountInstance is not valid for $ObjectSet');
  }
}
