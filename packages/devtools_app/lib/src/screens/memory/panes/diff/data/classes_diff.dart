// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/memory/classes.dart';
import '../../../../../shared/memory/heap_data.dart';
import '../../../../../shared/memory/retaining_path.dart';
import '../../../../../shared/primitives/utils.dart';

/// Comparison between two sets of objects.
class ObjectSetDiff {
  ObjectSetDiff({
    required ObjectSet? setBefore,
    required ObjectSet? setAfter,
    required HeapData dataBefore,
    required HeapData dataAfter,
  }) {
    final mapBefore = _toCodeToIndexMap(setBefore, dataBefore);
    final mapAfter = _toCodeToIndexMap(setAfter, dataAfter);

    final allCodes = mapBefore.keys.toSet().union(mapAfter.keys.toSet());

    for (var code in allCodes) {
      final before = mapBefore[code];
      final after = mapAfter[code];

      if (before != null && after != null) {
        _countInstance(persisted, after, dataAfter, setAfter!);
        continue;
      }

      if (before != null) {
        _countInstance(deleted, before, dataBefore, setBefore!);
        _uncountInstance(delta, before, dataBefore, setBefore);
        continue;
      }

      if (after != null) {
        _countInstance(created, after, dataAfter, setAfter!);
        _countInstance(delta, after, dataAfter, setAfter);
        continue;
      }

      assert(false);
    }

    assert(
      delta.instanceCount == created.instanceCount - deleted.instanceCount,
    );
  }

  static void _countInstance(
    ObjectSetStats setToAlter,
    int index,
    HeapData data,
    ObjectSet originalSet,
  ) {
    final excludeFromRetained =
        originalSet.objectsExcludedFromRetainedSize.contains(index);
    setToAlter.countInstance(
      data.graph,
      index,
      data.retainedSizes,
      excludeFromRetained: excludeFromRetained,
    );
  }

  static void _uncountInstance(
    ObjectSetStats setToAlter,
    int index,
    HeapData data,
    ObjectSet originalSet,
  ) {
    final excludeFromRetained =
        originalSet.objectsExcludedFromRetainedSize.contains(index);
    setToAlter.uncountInstance(
      data.graph,
      index,
      data.retainedSizes,
      excludeFromRetained: excludeFromRetained,
    );
  }

  static Map<int, int> _toCodeToIndexMap(
    ObjectSet? ids,
    HeapData? data,
  ) {
    if (ids == null || data == null) return const {};
    return {
      for (var id in ids.objects) data.graph.objects[id].identityHashCode: id,
    };
  }

  final created = ObjectSet();
  final deleted = ObjectSet();
  final persisted = ObjectSet();
  final delta = ObjectSetStats();

  bool get isZero => delta.isZero;
}

class DiffClassData extends ClassData {
  DiffClassData._(HeapClassName heapClass, this.diff, this.byPath)
      : super(className: heapClass);

  final ObjectSetDiff diff;

  @override
  ObjectSetStats get objects => diff.delta;

  @override
  final Map<PathFromRoot, ObjectSetStats> byPath;

  static DiffClassData? compare({
    required SingleClassData? before,
    required HeapData dataBefore,
    required SingleClassData? after,
    required HeapData dataAfter,
  }) {
    if (before == null && after == null) return null;
    final heapClass = (before?.className ?? after?.className)!;

    final result = DiffClassData._(
      heapClass,
      ObjectSetDiff(
        setBefore: before?.objects,
        setAfter: after?.objects,
        dataBefore: dataBefore,
        dataAfter: dataAfter,
      ),
      // PathFromRoot, ObjectSetStats
      subtractMaps<PathFromRoot, ObjectSetStats, ObjectSetStats,
          ObjectSetStats>(
        from: after?.byPath,
        subtract: before?.byPath,
        subtractor: ({subtract, from}) =>
            ObjectSetStats.subtract(subtract: subtract, from: from),
      ),
    );

    if (result.isZero()) return null;
    return result;
  }

  bool isZero() => diff.isZero;
}
