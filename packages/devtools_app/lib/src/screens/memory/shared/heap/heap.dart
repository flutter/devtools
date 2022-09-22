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
  HeapStatistics(this.recordsByClass);

  /// Maps full class name to stats record of this class.
  final Map<String, HeapClassStatistics> recordsByClass;
  late final List<HeapClassStatistics> records =
      recordsByClass.values.toList(growable: false);

  /// Mark the object as deeply immutable.
  ///
  /// There is no strong protection from mutation, just some asserts.
  void seal() {
    for (var record in records) {
      record.seal();
    }
  }
}

typedef SizesByPath = Map<ClassOnlyHeapPath, SizeOfClassSet>;

class HeapClassStatistics {
  HeapClassStatistics(this.heapClass)
      : _isSealed = false,
        total = SizeOfClassSet(),
        sizesByPath = {};

  HeapClassStatistics.negative(HeapClassStatistics other)
      : _isSealed = true,
        heapClass = other.heapClass,
        total = SizeOfClassSet.negative(other.total),
        sizesByPath = other.sizesByPath
            .map((key, value) => MapEntry(key, SizeOfClassSet.negative(value)));
  HeapClassStatistics.subtract(
    HeapClassStatistics minuend,
    HeapClassStatistics subtrahend,
  )   : assert(minuend.heapClass.fullName == subtrahend.heapClass.fullName),
        _isSealed = true,
        heapClass = minuend.heapClass,
        total = SizeOfClassSet.subtract(minuend.total, subtrahend.total),
        // ignore: dead_code
        sizesByPath =
            _subtractSizesByPath(minuend.sizesByPath, subtrahend.sizesByPath);

  static SizesByPath _subtractSizesByPath(SizesByPath left, SizesByPath rigth) {
    throw UnimplementedError('memory diff');
  }

  final HeapClass heapClass;
  final SizeOfClassSet total;
  final SizesByPath sizesByPath;

  void countInstance(AdaptedHeapData data, int objectIndex) {
    assert(!_isSealed);
    final object = data.objects[objectIndex];
    assert(object.heapClass.fullName == heapClass.fullName);
    total.countInstance(object);

    final path = data.retainingPath(objectIndex);
    if (path == null) return;
    final sizeForPath = sizesByPath.putIfAbsent(
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
    for (var size in sizesByPath.values) {
      size.seal();
    }
  }

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

  bool _isSealed;
}
