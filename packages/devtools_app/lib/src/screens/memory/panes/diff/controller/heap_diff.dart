// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../shared/heap/heap.dart';

/// Stores already calculated comparisons for heap couples.
class HeapDiffStore {
  final _store = <_HeapCouple, HeapComparison>{};

  HeapComparison compare(AdaptedHeap heap1, AdaptedHeap heap2) {
    final couple = _HeapCouple(heap1, heap2);
    return _store.putIfAbsent(couple, () => HeapComparison(couple));
  }
}

@immutable
class _HeapCouple {
  _HeapCouple(AdaptedHeap heap1, AdaptedHeap heap2) {
    older = _older(heap1, heap2);
    younger = older == heap1 ? heap2 : heap1;
  }

  late final AdaptedHeap older;
  late final AdaptedHeap younger;

  /// Tries to declare earliest heap in a determenistic way.
  ///
  /// If the earliest heap cannot be identified, returns the first argument.
  static AdaptedHeap _older(AdaptedHeap heap1, AdaptedHeap heap2) {
    assert(heap1.data != heap2.data);
    if (heap1.data.created.isBefore(heap2.data.created)) return heap1;
    if (heap2.data.created.isBefore(heap1.data.created)) return heap2;
    if (identityHashCode(heap1) < identityHashCode(heap2)) return heap1;
    if (identityHashCode(heap2) < identityHashCode(heap1)) return heap2;
    if (identityHashCode(heap1.data) < identityHashCode(heap2.data))
      return heap1;
    if (identityHashCode(heap2.data) < identityHashCode(heap1.data))
      return heap2;
    return heap1;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _HeapCouple &&
        other.older == older &&
        other.younger == younger;
  }

  @override
  int get hashCode => Object.hash(older, younger);
}

class HeapClassDiff {
  HeapClassDiff(HeapClassStatistics before, HeapClassStatistics after) {
    throw UnimplementedError();
  }
}

class HeapComparison {
  HeapComparison(this.heapCouple);

  final _HeapCouple heapCouple;

  late final HeapStatistics stats = _stats();

  HeapStatistics _stats() {
    // final statisticByClass = subtractMaps<String, HeapClassStatistics>(
    //   minuend: heapCouple.younger.stats.statsByClassName,
    //   subtrahend: heapCouple.older.stats.statsByClassName,
    //   subtract: (minuend, subtrahend) {
    //     final diff = HeapClassStatistics.subtract(minuend, subtrahend);
    //     if (diff.isZero) return null;
    //     return diff;
    //   },
    //   negate: (value) => HeapClassStatistics.negative(value),
    // );

    // return HeapStatistics(statisticByClass);

    throw UnimplementedError();
  }
}
