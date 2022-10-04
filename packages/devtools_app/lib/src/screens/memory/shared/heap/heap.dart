// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

class HeapStatistics {
  HeapStatistics(this.statsByClassName);

  /// Maps full class name to statistics of this class.
  final Map<String, HeapClassStatistics> statsByClassName;
  late final List<HeapClassStatistics> classStats =
      statsByClassName.values.toList(growable: false);

  /// Mark the object as deeply immutable.
  ///
  /// There is no strong protection from mutation, just some asserts.
  void seal() {
    for (var stats in classStats) {
      stats.seal();
    }
  }
}

class HeapClassStatistics {
  HeapClassStatistics(this.heapClass)
      : _isSealed = false,
        total = SizeOfClassSet(),
        sizeByRetainingPath = <ClassOnlyHeapPath, SizeOfClassSet>{};

  HeapClassStatistics.negative(HeapClassStatistics other)
      : _isSealed = true,
        heapClass = other.heapClass,
        total = SizeOfClassSet.negative(other.total),
        sizeByRetainingPath = other.sizeByRetainingPath
            .map((key, value) => MapEntry(key, SizeOfClassSet.negative(value)));

  HeapClassStatistics.subtract(
    HeapClassStatistics left,
    HeapClassStatistics right,
  )   : assert(left.heapClass.fullName == right.heapClass.fullName),
        _isSealed = true,
        heapClass = left.heapClass,
        total = SizeOfClassSet.subtract(left.total, right.total),
        // ignore: dead_code
        sizeByRetainingPath = throw UnimplementedError();

  final HeapClass heapClass;
  final SizeOfClassSet total;
  final Map<ClassOnlyHeapPath, SizeOfClassSet> sizeByRetainingPath;

  void countInstance(AdaptedHeapData data, int objectIndex) {
    assert(!_isSealed);
    final object = data.objects[objectIndex];
    assert(object.heapClass.fullName == heapClass.fullName);
    total.countInstance(object);

    final path = data.retainingPath(objectIndex);
    if (path == null) return;
    final sizeForPath = sizeByRetainingPath.putIfAbsent(
      ClassOnlyHeapPath(path),
      () => SizeOfClassSet(),
    );
    sizeForPath.countInstance(object);
  }

  bool get isZero => total.isZero;

  /// Mark the object as deeply immutable.
  ///
  /// There is no strong protection from mutation, just some asserts.
  void seal() {
    _isSealed = true;
    total.seal();
    for (var size in sizeByRetainingPath.values) {
      size.seal();
    }
  }

  /// See doc for the method [seal].
  bool _isSealed;
}

/// Size of set of instances.
class SizeOfClassSet {
  SizeOfClassSet() : _isSealed = false;

  SizeOfClassSet.negative(SizeOfClassSet other)
      : _isSealed = true,
        instanceCount = -other.instanceCount,
        shallowSize = -other.shallowSize,
        retainedSize = -other.retainedSize;

  SizeOfClassSet.subtract(SizeOfClassSet left, SizeOfClassSet right)
      : _isSealed = true,
        instanceCount = left.instanceCount - right.instanceCount,
        shallowSize = left.shallowSize - right.shallowSize,
        retainedSize = left.retainedSize - right.retainedSize;

  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(AdaptedHeapObject object) {
    assert(!_isSealed);
    retainedSize += object.retainedSize!;
    shallowSize += object.shallowSize;
    instanceCount++;
  }

  /// Mark the object as deeply immutable.
  ///
  /// There is no strong protection from mutation, just some asserts.
  void seal() => _isSealed = true;

  /// See doc for the method [seal].
  bool _isSealed;
}
