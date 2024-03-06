// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/heap/class_filter.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/memory/new/classes.dart';
import '../../../../../shared/memory/new/heap_data.dart';
import '../../../../../shared/memory/new/retaining_path.dart';

/// Comparison between two sets of objects.
class ObjectSetDiff {
  ObjectSetDiff({
    required ObjectSet? setBefore,
    required ObjectSet? setAfter,
    required HeapData? dataBefore,
    required HeapData? dataAfter,
  })  : assert((setBefore == null) == (dataBefore == null)),
        assert((setAfter == null) == (dataAfter == null)) {
    final mapBefore = _toCodeToIndexMap(setBefore, dataBefore);
    final mapAfter = _toCodeToIndexMap(setAfter, dataAfter);

    final allCodes = mapBefore.keys.toSet().union(mapAfter.keys.toSet());

    for (var code in allCodes) {
      final before = mapBefore[code];
      final after = mapAfter[code];

      if (before != null && after != null) {
        _countInstance(persisted, after, dataAfter!, setAfter!);
        continue;
      }

      if (before != null) {
        _countInstance(deleted, before, dataBefore!, setBefore!);
        _uncountInstance(delta, before, dataBefore, setBefore);
        continue;
      }

      if (after != null) {
        _countInstance(created, after, dataAfter!, setAfter!);
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
      for (var id in ids.objects) data.graph.objects[id].hashCode: id,
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
      : super(heapClass: heapClass);

  final ObjectSetDiff diff;

  @override
  ObjectSetStats get objects => diff.delta;

  @override
  final Map<PathFromRoot, ObjectSetStats> byPath;

  static DiffClassData? compare({
    required SingleClassData? before,
    required HeapData? dataBefore,
    required SingleClassData? after,
    required HeapData? dataAfter,
  }) {
    assert((before == null) == (dataBefore == null));
    assert((before == null) == (dataAfter == null));

    if (before == null && after == null) return null;
    final heapClass = (before?.heapClass ?? after?.heapClass)!;

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

// ///////////////////
// ///
// ///

// /// List of classes with per-class comparison between two heaps.
// class DiffHeapClasses extends HeapClasses_<DiffClassStats>
//     with FilterableHeapClasses_<DiffClassStats> {
//   DiffHeapClasses._(_HeapCouple couple)
//       : before = couple.older.data,
//         after = couple.younger.data {
//     classesByName = subtractMaps<HeapClassName, SingleClassStats_,
//         SingleClassStats_, DiffClassStats>(
//       from: couple.younger.classes.classesByName,
//       substract: couple.older.classes.classesByName,
//       subtractor: ({subtract, from}) =>
//           DiffClassStats.diff(before: subtract, after: from),
//     );
//   }

//   /// Maps full class name to class.
//   late final Map<HeapClassName, DiffClassStats> classesByName;
//   late final List<DiffClassStats> classes =
//       classesByName.values.toList(growable: false);
//   final AdaptedHeapData before;
//   final AdaptedHeapData after;

//   @override
//   void seal() {
//     super.seal();
//     for (var c in classes) {
//       c.seal();
//     }
//   }

//   @override
//   List<DiffClassStats> get classStatsList => classes;
// }

// /// Comparison between two heaps for a class.
// class DiffClassStats extends ClassStats_ {
//   DiffClassStats._({
//     required super.statsByPath,
//     required super.heapClass,
//     required this.total,
//   });

//   final ObjectSetDiff_ total;

//   static DiffClassStats? diff({
//     required SingleClassStats_? before,
//     required SingleClassStats_? after,
//   }) {
//     if (before == null && after == null) return null;

//     final heapClass = (before?.heapClass ?? after?.heapClass)!;

//     final result = DiffClassStats._(
//       heapClass: heapClass,
//       total: ObjectSetDiff_(
//         setBefore: before?.objects,
//         setAfter: after?.objects,
//       ),
//       statsByPath: subtractMaps<ClassOnlyHeapPath, ObjectSetStats_,
//           ObjectSetStats_, ObjectSetStats_>(
//         from: after?.statsByPath,
//         substract: before?.statsByPath,
//         subtractor: ({subtract, from}) =>
//             ObjectSetStats_.subtract(subtract: subtract, from: from),
//       ),
//     );

//     if (result.isZero()) return null;
//     return result..seal();
//   }

//   bool isZero() => total.isZero;
// }

// /// Comparison between two sets of objects.
// class ObjectSetDiff_ {
//   ObjectSetDiff_({ObjectSet_? setBefore, ObjectSet_? setAfter}) {
//     setBefore ??= ObjectSet_.empty;
//     setAfter ??= ObjectSet_.empty;

//     final allCodes = _unionCodes(setBefore, setAfter);

//     for (var code in allCodes) {
//       final before = setBefore.objectsByCodes[code];
//       final after = setAfter.objectsByCodes[code];

//       if (before != null && after != null) {
//         // When an object exists both before and after
//         // the state 'after' is more interesting for user
//         // about the retained size.
//         final excludeFromRetained =
//             setAfter.objectsExcludedFromRetainedSize.contains(after.code);
//         persisted.countInstance(
//           after,
//           excludeFromRetained: excludeFromRetained,
//         );
//         continue;
//       }

//       if (before != null) {
//         final excludeFromRetained =
//             setBefore.objectsExcludedFromRetainedSize.contains(before.code);
//         deleted.countInstance(before, excludeFromRetained: excludeFromRetained);
//         delta.uncountInstance(before, excludeFromRetained: excludeFromRetained);
//         continue;
//       }

//       if (after != null) {
//         final excludeFromRetained =
//             setAfter.objectsExcludedFromRetainedSize.contains(after.code);
//         created.countInstance(after, excludeFromRetained: excludeFromRetained);
//         delta.countInstance(after, excludeFromRetained: excludeFromRetained);
//         continue;
//       }

//       assert(false);
//     }
//     created.seal();
//     deleted.seal();
//     persisted.seal();
//     delta.seal();
//     assert(
//       delta.instanceCount == created.instanceCount - deleted.instanceCount,
//     );
//   }

//   static Set<IdentityHashCode> _unionCodes(ObjectSet_ set1, ObjectSet_ set2) {
//     final codesBefore = set1.objectsByCodes.keys.toSet();
//     final codesAfter = set2.objectsByCodes.keys.toSet();

//     return codesBefore.union(codesAfter);
//   }

//   final created = ObjectSet_();
//   final deleted = ObjectSet_();
//   final persisted = ObjectSet_();
//   final delta = ObjectSetStats_();

//   bool get isZero => delta.isZero;
// }
