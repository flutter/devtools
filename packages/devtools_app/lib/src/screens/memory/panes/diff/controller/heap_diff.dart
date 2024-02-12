// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/analytics/metrics.dart';
import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/memory/new/heap_api.dart';
import '../../../../../shared/memory/simple_items.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';

/// Stores already calculated comparisons for heap couples.
class HeapDiffStore {
  HeapDiffStore();

  final _store = <_HeapCouple, DiffHeapClasses>{};

  DiffHeapClasses compare_(AdaptedHeap heap1, AdaptedHeap heap2) {
    final couple = _HeapCouple(heap1, heap2);
    return _store.putIfAbsent(couple, () => _calculateDiffGaWrapper(couple));
  }

  DiffHeapClasses compare(Heap heap1, Heap heap2) {
    throw UnimplementedError();
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
class DiffHeapClasses extends HeapClasses<DiffClassStats>
    with FilterableHeapClasses<DiffClassStats> {
  DiffHeapClasses._(_HeapCouple couple)
      : before = couple.older.data,
        after = couple.younger.data {
    classesByName = subtractMaps<HeapClassName, SingleClassStats,
        SingleClassStats, DiffClassStats>(
      from: couple.younger.classes.classesByName,
      substract: couple.older.classes.classesByName,
      subtractor: ({subtract, from}) =>
          DiffClassStats.diff(before: subtract, after: from),
    );
  }

  /// Maps full class name to class.
  late final Map<HeapClassName, DiffClassStats> classesByName;
  late final List<DiffClassStats> classes =
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
  List<DiffClassStats> get classStatsList => classes;
}

/// Comparison between two heaps for a class.
class DiffClassStats extends ClassStats {
  DiffClassStats._({
    required super.statsByPath,
    required super.heapClass,
    required this.total,
  });

  final ObjectSetDiff total;

  static DiffClassStats? diff({
    required SingleClassStats? before,
    required SingleClassStats? after,
  }) {
    if (before == null && after == null) return null;

    final heapClass = (before?.heapClass ?? after?.heapClass)!;

    final result = DiffClassStats._(
      heapClass: heapClass,
      total: ObjectSetDiff(
        setBefore: before?.objects,
        setAfter: after?.objects,
      ),
      statsByPath: subtractMaps<ClassOnlyHeapPath, ObjectSetStats,
          ObjectSetStats, ObjectSetStats>(
        from: after?.statsByPath,
        substract: before?.statsByPath,
        subtractor: ({subtract, from}) =>
            ObjectSetStats.subtract(subtract: subtract, from: from),
      ),
    );

    if (result.isZero()) return null;
    return result..seal();
  }

  bool isZero() => total.isZero;
}

/// Comparison between two sets of objects.
class ObjectSetDiff {
  ObjectSetDiff({ObjectSet? setBefore, ObjectSet? setAfter}) {
    setBefore ??= ObjectSet.empty;
    setAfter ??= ObjectSet.empty;

    final allCodes = _unionCodes(setBefore, setAfter);

    for (var code in allCodes) {
      final before = setBefore.objectsByCodes[code];
      final after = setAfter.objectsByCodes[code];

      if (before != null && after != null) {
        // When an object exists both before and after
        // the state 'after' is more interesting for user
        // about the retained size.
        final excludeFromRetained =
            setAfter.objectsExcludedFromRetainedSize.contains(after.code);
        persisted.countInstance(
          after,
          excludeFromRetained: excludeFromRetained,
        );
        continue;
      }

      if (before != null) {
        final excludeFromRetained =
            setBefore.objectsExcludedFromRetainedSize.contains(before.code);
        deleted.countInstance(before, excludeFromRetained: excludeFromRetained);
        delta.uncountInstance(before, excludeFromRetained: excludeFromRetained);
        continue;
      }

      if (after != null) {
        final excludeFromRetained =
            setAfter.objectsExcludedFromRetainedSize.contains(after.code);
        created.countInstance(after, excludeFromRetained: excludeFromRetained);
        delta.countInstance(after, excludeFromRetained: excludeFromRetained);
        continue;
      }

      assert(false);
    }
    created.seal();
    deleted.seal();
    persisted.seal();
    delta.seal();
    assert(
      delta.instanceCount == created.instanceCount - deleted.instanceCount,
    );
  }

  static Set<IdentityHashCode> _unionCodes(ObjectSet set1, ObjectSet set2) {
    final codesBefore = set1.objectsByCodes.keys.toSet();
    final codesAfter = set2.objectsByCodes.keys.toSet();

    return codesBefore.union(codesAfter);
  }

  final created = ObjectSet();
  final deleted = ObjectSet();
  final persisted = ObjectSet();
  final delta = ObjectSetStats();

  bool get isZero => delta.isZero;
}
