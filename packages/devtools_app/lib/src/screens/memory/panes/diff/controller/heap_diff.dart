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

class DiffClassStats extends ClassStats {
  DiffClassStats(SingleClassStats before, SingleClassStats after) {
    throw UnimplementedError();
  }
}

class DiffHeapClasses extends HeapClasses {
  DiffHeapClasses(_HeapCouple heapCouple) {
    classesByName =
        subtractMaps<HeapClassName, SingleClassStats, DiffClassStats>(
      minuend: heapCouple.younger.classes.classesByName,
      subtrahend: heapCouple.older.classes.classesByName,
      subtract: _subtruct,
    );
  }

  static DiffClassStats? _subtruct(
      SingleClassStats? left, SingleClassStats? right) {
    // (minuend, subtrahend) {
    //   final diff = HeapClassStatistics.subtract(minuend, subtrahend);
    //   if (diff.isZero) return null;
    //   return diff;
    // },
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
