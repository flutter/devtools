// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';

/// Stores already calculated comparisons for heap couples.
class HeapDiffStore {
  final _store = <_HeapCouple, DiffHeapClasses>{};

  DiffHeapClasses compare(AdaptedHeap heap1, AdaptedHeap heap2) {
    final couple = _HeapCouple(heap1, heap2);
    return _store.putIfAbsent(couple, () => DiffHeapClasses(couple));
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

class DiffHeapClasses extends HeapClasses {
  DiffHeapClasses(_HeapCouple couple) {
    classesByName =
        subtractMaps<HeapClassName, SingleClassStats, DiffClassStats>(
      minuend: couple.younger.classes.classesByName,
      subtrahend: couple.older.classes.classesByName,
      subtract: (before, after) => DiffClassStats.diff(before, after),
    );
  }

  /// Maps full class name to class.
  late Map<HeapClassName, DiffClassStats> classesByName;
  late final List<DiffClassStats> classes =
      classesByName.values.toList(growable: false);

  @override
  void seal() {
    super.seal();
    for (var c in classes) {
      c.seal();
    }
  }
}

class DiffClassStats extends ClassStats {
  DiffClassStats._({required this.total, required this.statsByPath});

  final ObjectSetDiff total;
  final ObjectStatsByPath statsByPath;

  static DiffClassStats? diff(
    SingleClassStats? before,
    SingleClassStats? after,
  ) {
    if (before == null && after == null) return null;
    final result = DiffClassStats._(
      total: ObjectSetDiff(before: before?.objects, after: after?.objects),
      statsByPath:
          subtractMaps<ClassOnlyHeapPath, ObjectSetStats, ObjectSetStats>(
        minuend: after?.objectsByPath,
        subtrahend: before?.objectsByPath,
        subtract: (minuend, subtrahend) =>
            ObjectSetStats.subtruct(minuend: minuend, subtrahend: subtrahend),
      ),
    );

    if (result.isZero()) return null;
    return result..seal();
  }

  bool isZero() => total.isZero;
}

class ObjectSetDiff {
  ObjectSetDiff({ObjectSet? before, ObjectSet? after}) {
    before ??= ObjectSet.empty;
    after ??= ObjectSet.empty;

    final objects = before.objects.union(after.objects);
    for (var object in objects) {
      if (before.objects.contains(object) && (after.objects.contains(object)))
        continue;

      if (before.objects.contains(object)) {
        deleted.countInstance(object);
        delta.uncountInstance(object);
        continue;
      }
      if (after.objects.contains(object)) {
        created.countInstance(object);
        delta.countInstance(object);
        continue;
      }
      assert(false);
    }
    created.seal();
    deleted.seal();
    delta.seal();
  }

  final created = ObjectSet();
  final deleted = ObjectSet();
  final delta = ObjectSetStats();

  bool get isZero => delta.isZero;
}
