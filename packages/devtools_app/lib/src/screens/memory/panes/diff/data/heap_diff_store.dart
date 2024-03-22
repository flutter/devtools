// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/analytics/metrics.dart';
import '../../../../../shared/memory/heap_data.dart';
import 'heap_diff_data.dart';

/// Stores already calculated comparisons for heap couples.
class HeapDiffStore {
  HeapDiffStore();

  final _store = <_HeapCouple, HeapDiffData>{};

  HeapDiffData? compare(HeapData? heap1, HeapData? heap2) {
    if (heap1 == null || heap2 == null) return null;
    final couple = _HeapCouple(heap1, heap2);
    return _store.putIfAbsent(couple, () => _calculateDiffGaWrapper(couple));
  }
}

HeapDiffData _calculateDiffGaWrapper(_HeapCouple couple) {
  late final HeapDiffData result;
  ga.timeSync(
    gac.memory,
    gac.MemoryTime.calculateDiff,
    syncOperation: () => result =
        calculateHeapDiffData(before: couple.before, after: couple.after),
    screenMetricsProvider: () => MemoryScreenMetrics(
      heapDiffObjectsBefore: couple.before.graph.objects.length,
      heapDiffObjectsAfter: couple.after.graph.objects.length,
    ),
  );
  return result;
}

@immutable
class _HeapCouple {
  _HeapCouple(HeapData heap1, HeapData heap2) {
    before = _older(heap1, heap2);
    after = before == heap1 ? heap2 : heap1;
  }

  late final HeapData before;
  late final HeapData after;

  /// Tries to declare earliest heap in a deterministic way.
  static HeapData _older(HeapData heap1, HeapData heap2) {
    assert(heap1.graph != heap2.graph);
    if (heap1.created.isBefore(heap2.created)) return heap1;
    if (heap2.created.isBefore(heap1.created)) return heap2;
    if (identityHashCode(heap1) < identityHashCode(heap2)) return heap1;
    if (identityHashCode(heap2) < identityHashCode(heap1)) return heap2;
    return heap1;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _HeapCouple &&
        other.before == before &&
        other.after == after;
  }

  @override
  int get hashCode => Object.hash(before.graph, after.graph);
}
