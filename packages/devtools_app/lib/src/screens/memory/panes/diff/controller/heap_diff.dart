// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../analytics/analytics.dart' as ga;
import '../../../../../analytics/constants.dart' as analytics_constants;
import '../../../../../primitives/utils.dart';
import '../../../primitives/class_name.dart';
import '../../../primitives/simple_elements.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';

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
    analytics_constants.memory,
    analytics_constants.MemoryTime.calculateDiff,
    syncOperation: () => result = DiffHeapClasses(couple),
    screenMetricsProvider: () => MemoryAnalyticsMetrics(
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

/// List of classes with per-class comparision between two heaps.
class DiffHeapClasses extends HeapClasses<DiffClassStats>
    with FilterableHeapClasses<DiffClassStats> {
  DiffHeapClasses(_HeapCouple couple) {
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

/// Comparision between two heaps for a class.
class DiffClassStats extends ClassStats {
  DiffClassStats._({
    required this.heapClass,
    required this.total,
    required StatsByPath objectsByPath,
  }) : super(objectsByPath);

  @override
  final HeapClassName heapClass;

  final ObjectSetDiff total;

  static DiffClassStats? diff({
    required SingleClassStats? before,
    required SingleClassStats? after,
  }) {
    if (before == null && after == null) return null;

    final heapClass = (before?.heapClass ?? after?.heapClass)!;

    final result = DiffClassStats._(
      heapClass: heapClass,
      total: ObjectSetDiff(before: before?.objects, after: after?.objects),
      objectsByPath: subtractMaps<ClassOnlyHeapPath, ObjectSetStats,
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

/// Comparision between two sets of objects.
class ObjectSetDiff {
  ObjectSetDiff({ObjectSet? before, ObjectSet? after}) {
    before ??= ObjectSet.empty;
    after ??= ObjectSet.empty;

    final codesBefore = before.objectsByCodes.keys.toSet();
    final codesAfter = after.objectsByCodes.keys.toSet();

    final allCodes = codesBefore.union(codesAfter);
    for (var code in allCodes) {
      final inBefore = codesBefore.contains(code);
      final inAfter = codesAfter.contains(code);
      if (inBefore && inAfter) continue;

      final object = before.objectsByCodes[code] ?? after.objectsByCodes[code]!;

      if (inBefore) {
        deleted.countInstance(object);
        delta.uncountInstance(object);
        continue;
      }
      if (inAfter) {
        created.countInstance(object);
        delta.countInstance(object);
        continue;
      }
      assert(false);
    }
    created.seal();
    deleted.seal();
    delta.seal();
    assert(
      delta.instanceCount == created.instanceCount - deleted.instanceCount,
    );
  }

  final created = ObjectSet();
  final deleted = ObjectSet();
  final delta = ObjectSetStats();

  bool get isZero => delta.isZero;
}
