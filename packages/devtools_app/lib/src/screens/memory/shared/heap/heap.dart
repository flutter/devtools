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
    final result = <String, HeapStatsRecord>{};
    if (!data.isSpanningTreeBuilt) buildSpanningTree(data);

    for (var i in Iterable.generate(data.objects.length)) {
      final object = data.objects[i];
      final heapClass = object.heapClass;

      // We do not show objects that will be garbage collected soon or are
      // native.
      if (object.retainedSize == null || heapClass.isSentinel) continue;

      final fullName = heapClass.fullName;

      final stats =
          result.putIfAbsent(fullName, () => HeapStatsRecord(heapClass));
      stats.countInstance(data, i);
    }

    return HeapStatistics(result);
  }
}

class HeapStatistics {
  HeapStatistics(this.recordsByClass);

  /// Maps full class name to stats record of this class.
  final Map<String, HeapStatsRecord> recordsByClass;
  late final List<HeapStatsRecord> records =
      recordsByClass.values.toList(growable: false);
}

class HeapStatsRecord {
  HeapStatsRecord(this.heapClass)
      : _isSealed = false,
        total = SizeOfSet(),
        byRetainingPath = <String, SizeOfSet>{};

  HeapStatsRecord.negative(HeapStatsRecord other)
      : _isSealed = true,
        heapClass = other.heapClass,
        total = SizeOfSet.negative(other.total),
        byRetainingPath = <String, SizeOfSet>{}; // ???

  HeapStatsRecord.subtract(HeapStatsRecord left, HeapStatsRecord right)
      : assert(left.heapClass.fullName == right.heapClass.fullName),
        _isSealed = true,
        heapClass = left.heapClass,
        total = SizeOfSet.subtract(left.total, right.total),
        byRetainingPath = <String, SizeOfSet>{}; // ???

  final HeapClass heapClass;
  final SizeOfSet total;
  final Map<String, SizeOfSet> byRetainingPath;

  void countInstance(AdaptedHeapData data, int onbjectIndex) {
    assert(!_isSealed);
    // ???
    final object = data.objects[onbjectIndex];
    assert(object.heapClass.fullName == heapClass.fullName);
    total.countInstance(object);
    // final path = object.
  }

  bool get isZero => total.isZero;

  /// Mark the object as immutable.
  ///
  /// There is no strong protection from mutation, just some asserts.
  void seal() {
    _isSealed = true;
    total.seal();
  }

  bool _isSealed;
}

/// Size of set of instances.
class SizeOfSet {
  SizeOfSet() : _isSealed = false;

  SizeOfSet.negative(SizeOfSet other)
      : _isSealed = true,
        instanceCount = -other.instanceCount,
        shallowSize = -other.shallowSize,
        retainedSize = -other.retainedSize;

  SizeOfSet.subtract(SizeOfSet left, SizeOfSet right)
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

  /// Mark the object as immutable.
  ///
  /// There is no strong protection from mutation, just some asserts.
  void seal() => _isSealed = true;

  bool _isSealed;
}
