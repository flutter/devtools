// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../shared/utils.dart';
import 'model.dart';
import 'spanning_tree.dart';

class AdaptedHeap {
  AdaptedHeap(this.data);

  final AdaptedHeapData data;

  late final HeapStatistics stats = _heapStatistics(data);

  static HeapStatistics _heapStatistics(AdaptedHeapData data) {
    final result = <String, HeapClassStatistics>{};
    if (!data.isSpanningTreeBuilt) buildSpanningTree(data);

    for (var i in Iterable.generate(data.objects.length)) {
      final object = data.objects[i];
      final heapClass = object.heapClass;

      // We do not show objects that will be garbage collected soon or are
      // native.
      if (object.retainedSize == null || heapClass.isSentinel) continue;

      final fullName = heapClass.fullName;

      final stats =
          result.putIfAbsent(fullName, () => HeapClassStatistics(heapClass));
      stats.countInstance(data, i);
    }

    return HeapStatistics(result)..seal();
  }
}

class HeapStatistics with Sealable {
  HeapStatistics(this.statsByClassName);

  /// Maps full class name to statistics of this class.
  final Map<String, HeapClassStatistics> statsByClassName;
  late final List<HeapClassStatistics> classStats =
      statsByClassName.values.toList(growable: false);

  @override
  void seal() {
    super.seal();
    for (var stats in classStats) {
      stats.seal();
    }
  }
}

typedef ObjectsByPath = Map<ClassOnlyHeapPath, ObjectSet>;

class HeapClassStatistics with Sealable {
  HeapClassStatistics(this.heapClass)
      : total = ObjectSet(),
        objectsByPath = <ClassOnlyHeapPath, ObjectSet>{};

  HeapClassStatistics.negative(HeapClassStatistics other)
      : heapClass = other.heapClass,
        total = ObjectSet.negative(other.total),
        objectsByPath = other.objectsByPath
            .map((key, value) => MapEntry(key, ObjectSet.negative(value))) {
    seal();
  }

  HeapClassStatistics.subtract(
    HeapClassStatistics minuend,
    HeapClassStatistics subtrahend,
  )   : assert(minuend.heapClass.fullName == subtrahend.heapClass.fullName),
        heapClass = minuend.heapClass,
        total = ObjectSet.subtract(minuend.total, subtrahend.total),
        objectsByPath = _subtractSizesByPath(
            minuend.objectsByPath, subtrahend.objectsByPath) {
    seal();
  }

  static ObjectsByPath _subtractSizesByPath(
    ObjectsByPath minuend,
    ObjectsByPath subtrahend,
  ) =>
      subtractMaps<ClassOnlyHeapPath, ObjectSet>(
        minuend: minuend,
        subtrahend: subtrahend,
        subtract: (minuend, subtrahend) {
          final diff = ObjectSet.subtract(minuend, subtrahend);
          if (diff.isZero) return null;
          return diff;
        },
        negate: (value) => ObjectSet.negative(value),
      );

  final HeapClass heapClass;
  final ObjectSet total;
  final ObjectsByPath objectsByPath;

  void countInstance(AdaptedHeapData data, int objectIndex) {
    assert(!isSealed);
    final object = data.objects[objectIndex];
    assert(object.heapClass.fullName == heapClass.fullName);
    total.countInstance(object);

    final path = data.retainingPath(objectIndex);
    if (path == null) return;
    final sizeForPath = objectsByPath.putIfAbsent(
      ClassOnlyHeapPath(path),
      () => ObjectSet(),
    );
    sizeForPath.countInstance(object);
  }

  bool get isZero => total.isZero;
}

class ObjectSetDiff with Sealable {
  final created = ObjectSet();
  final deleted = ObjectSet();
  final delta = ObjectSet();
}

/// Size of set of instances.
class ObjectSet with Sealable {
  ObjectSet();

  ObjectSet.negative(ObjectSet other)
      : instanceCount = -other.instanceCount,
        shallowSize = -other.shallowSize,
        retainedSize = -other.retainedSize {
    seal();
  }

  ObjectSet.subtract(ObjectSet left, ObjectSet right)
      : instanceCount = left.instanceCount - right.instanceCount,
        shallowSize = left.shallowSize - right.shallowSize,
        retainedSize = left.retainedSize - right.retainedSize {
    seal();
  }

  final codes = <int>{};
  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(AdaptedHeapObject object) {
    assert(!isSealed);
    if (codes.contains(object.code)) return;
    codes.add(object.code);
    retainedSize += object.retainedSize!;
    shallowSize += object.shallowSize;
    instanceCount++;
  }
}
