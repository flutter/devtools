// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../../shared/memory/retaining_path.dart';
import '../../../../../shared/memory/simple_items.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../shared/heap/heap.dart';

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

/// Comparison between two heaps for a class.
class DiffClassData extends ClassData {
  DiffClassData._({
    required super.statsByPath,
    required super.heapClass,
    required this.total,
  });

  final ObjectSetDiff total;

  static DiffClassData? diff({
    required SingleClassStats? before,
    required SingleClassStats? after,
  }) {
    if (before == null && after == null) return null;

    final heapClass = (before?.heapClass ?? after?.heapClass)!;

    final result = DiffClassData._(
      heapClass: heapClass,
      total: ObjectSetDiff(
        setBefore: before?.objects,
        setAfter: after?.objects,
      ),
      statsByPath: subtractMaps<PathFromRoot, ObjectSetStats, ObjectSetStats,
          ObjectSetStats>(
        from: after?.statsByPath,
        subtract: before?.statsByPath,
        subtractor: ({subtract, from}) =>
            ObjectSetStats.subtract(subtract: subtract, from: from),
      ),
    );

    if (result.isZero()) return null;
    return result..seal();
  }

  bool isZero() => total.isZero;
}
