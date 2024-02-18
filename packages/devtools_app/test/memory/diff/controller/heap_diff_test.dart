// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/controller/heap_diff.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/heap.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/spanning_tree.dart';
import 'package:devtools_app/src/shared/memory/adapted_heap_data.dart';
import 'package:devtools_app/src/shared/memory/adapted_heap_object.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '$HeapDiffStore does not create new $DiffHeapClasses for the same couple',
    () async {
      final heap1 = await _createSimplestHeap();
      final heap2 = await _createSimplestHeap();

      expect(heap1 == heap2, false);

      final store = HeapDiffStore();

      final couple1 = identityHashCode(store.compare_(heap1, heap2));
      final couple2 = identityHashCode(store.compare_(heap1, heap2));
      final couple3 = identityHashCode(store.compare_(heap2, heap1));

      expect(couple1, couple2);
      expect(couple1, couple3);
    },
  );

  test('$DiffClassStats calculates mix of cases as expected', () async {
    final className =
        HeapClassName.fromPath(className: 'myClass', library: 'library');

    final deleted = _createObject(className, 1, {});
    final persistedBefore = _createObject(className, 2, {});
    final persistedAfter = _createObject(className, 2, {});
    final created1 = _createObject(className, 3, {});
    final created2 = _createObject(className, 4, {});

    final statsBefore = await _createClassStats({deleted, persistedBefore});
    final statsAfter =
        await _createClassStats({persistedAfter, created1, created2});

    final stats = DiffClassStats.diff(before: statsBefore, after: statsAfter)!;

    expect(stats.heapClass, className);
    expect(stats.total.created.instanceCount, 2);
    expect(stats.total.deleted.instanceCount, 1);
    expect(stats.total.delta.instanceCount, 1);
    expect(stats.total.persisted.instanceCount, 1);
  });

  test('$DiffClassStats calculates deletion as expected', () async {
    final className =
        HeapClassName.fromPath(className: 'myClass', library: 'library');

    final deleted = _createObject(className, 1, {});

    final statsBefore = await _createClassStats({deleted});

    final stats = DiffClassStats.diff(before: statsBefore, after: null)!;

    expect(stats.heapClass, className);
    expect(stats.total.created.instanceCount, 0);
    expect(stats.total.deleted.instanceCount, 1);
    expect(stats.total.delta.instanceCount, -1);
    expect(stats.total.persisted.instanceCount, 0);
  });
}

Future<SingleClassStats_> _createClassStats(
  Set<MockAdaptedHeapObject> instances,
) async {
  final indexes =
      Iterable<int>.generate(instances.length).map((i) => i + 1).toSet();

  final objects = [
    _createObject(
      HeapClassName.fromPath(className: 'root', library: 'lib'),
      0,
      indexes,
    ),
    ...instances,
  ];

  final heap = AdaptedHeapData(
    objects,
    rootIndex: 0,
  );
  await calculateHeap(heap);

  final result = SingleClassStats_(heapClass: instances.first.heapClass);
  for (var index in indexes) {
    result.countInstance(heap, index);
  }

  return result;
}

MockAdaptedHeapObject _createObject(
  HeapClassName className,
  int code,
  Set<int> references,
) =>
    MockAdaptedHeapObject(
      code: code,
      outRefs: references,
      heapClass: className,
      shallowSize: 1,
    );

Future<AdaptedHeap> _createSimplestHeap() async => await AdaptedHeap.create(
      AdaptedHeapData(
        [
          MockAdaptedHeapObject(
            code: 0,
            outRefs: {},
            heapClass:
                HeapClassName.fromPath(className: 'root', library: 'lib'),
            shallowSize: 1,
          ),
        ],
        rootIndex: 0,
      ),
    );
