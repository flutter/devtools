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

  /// Finds most deterministic way to declare earliest heap.
  ///
  /// If earliest heap cannot be identified, returns first argument.
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

class HeapComparison {
  HeapComparison(this.heapCouple);

  late final HeapStatistics stats = _stats();

  final _HeapCouple heapCouple;

  HeapStatistics _stats() {
    final result = <String, HeapStatsRecord>{};

    final older = heapCouple.older.stats.recordsByClass;
    final younger = heapCouple.younger.stats.recordsByClass;

    final unionOfKeys = older.keys.toSet().union(younger.keys.toSet());

    for (var key in unionOfKeys) {
      final olderRecord = older[key];
      final youngerRecord = younger[key];

      if (olderRecord != null && youngerRecord != null) {
        final diff = HeapStatsRecord.subtract(olderRecord, youngerRecord);
        if (!diff.isZero) result[key] = diff;
      } else if (youngerRecord != null) {
        result[key] = youngerRecord;
      } else {
        result[key] = HeapStatsRecord.negative(olderRecord!);
      }
    }

    return HeapStatistics(result);
  }
}
