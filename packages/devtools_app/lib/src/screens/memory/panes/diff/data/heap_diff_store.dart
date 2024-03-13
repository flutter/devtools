// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/analytics/metrics.dart';
import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import 'classes_diff.dart';

/// Stores already calculated comparisons for heap couples.
class HeapDiffStore {
  HeapDiffStore();

  final _store = <_HeapCouple, DiffHeapClasses>{};

  DiffHeapClasses compare(AdaptedHeap heap1, AdaptedHeap heap2) {
    final couple = _HeapCouple(heap1, heap2);
    return _store.putIfAbsent(couple, () => _calculateDiffGaWrapper(couple));
  }
}

DiffHeapClasses _calculateDiffGaWrapper(_HeapCouple couple) {
  late final DiffHeapClasses result;
  ga.timeSync(
    gac.memory,
    gac.MemoryTime.calculateDiff,
    syncOperation: () => result = DiffHeapClasses._(couple),
    screenMetricsProvider: () => MemoryScreenMetrics(
      heapDiffObjectsBefore: couple.older.data.objects.length,
      heapDiffObjectsAfter: couple.younger.data.objects.length,
    ),
  );
  return result;
}

@immutable
class _HeapCouple {
  _HeapCouple(AdaptedHeap heap1, AdaptedHeap heap2) {
    older = _older(heap1, heap2);
    younger = older == heap1 ? heap2 : heap1;
  }

  late final AdaptedHeap older;
  late final AdaptedHeap younger;

  /// Tries to declare earliest heap in a deterministic way.
  ///
  /// If the earliest heap cannot be identified, returns the first argument.
  static AdaptedHeap _older(AdaptedHeap heap1, AdaptedHeap heap2) {
    assert(heap1.data != heap2.data);
    if (heap1.data.created.isBefore(heap2.data.created)) return heap1;
    if (heap2.data.created.isBefore(heap1.data.created)) return heap2;
    if (identityHashCode(heap1) < identityHashCode(heap2)) return heap1;
    if (identityHashCode(heap2) < identityHashCode(heap1)) return heap2;
    if (identityHashCode(heap1.data) < identityHashCode(heap2.data)) {
      return heap1;
    }
    if (identityHashCode(heap2.data) < identityHashCode(heap1.data)) {
      return heap2;
    }
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

/// List of classes with per-class comparison between two heaps.
class DiffHeapClasses extends HeapClasses<DiffClassData>
    with FilterableHeapClasses<DiffClassData> {
  DiffHeapClasses._(_HeapCouple couple)
      : before = couple.older.data,
        after = couple.younger.data {
    classesByName = subtractMaps<HeapClassName, SingleClassStats,
        SingleClassStats, DiffClassData>(
      from: couple.younger.classes.classesByName,
      subtract: couple.older.classes.classesByName,
      subtractor: ({subtract, from}) =>
          DiffClassData.diff(before: subtract, after: from),
    );
  }

  /// Maps full class name to class.
  late final Map<HeapClassName, DiffClassData> classesByName;
  late final List<DiffClassData> classes =
      classesByName.values.toList(growable: false);
  final AdaptedHeapData before;
  final AdaptedHeapData after;

  @override
  void seal() {
    super.seal();
    for (var c in classes) {
      c.seal();
    }
  }

  @override
  List<DiffClassData> get classStatsList => classes;
}
