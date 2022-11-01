// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/controller/heap_diff.dart';
import 'package:devtools_app/src/screens/memory/primitives/class_name.dart';

import 'package:devtools_app/src/screens/memory/shared/heap/heap.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/spanning_tree.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      '$HeapDiffStore does not create new $DiffHeapClasses for the same couple',
      () {
    final heap1 = _createSimplestHeap();
    final heap2 = _createSimplestHeap();

    expect(heap1 == heap2, false);

    final store = HeapDiffStore();

    final couple1 = identityHashCode(store.compare(heap1, heap2));
    final couple2 = identityHashCode(store.compare(heap1, heap2));
    final couple3 = identityHashCode(store.compare(heap2, heap1));

    expect(couple1, couple2);
    expect(couple1, couple3);
  });

  test('$DiffClassStats calculates mix of cases as expected', () {
    final className = HeapClassName(className: 'myClass', library: 'library');

    final deleted = _createObject(className, 1, []);
    final persistedBefore = _createObject(className, 2, []);
    final persistedAfter = _createObject(className, 2, []);
    final created1 = _createObject(className, 3, []);
    final created2 = _createObject(className, 4, []);

    final statsBefore = _createClassStats([deleted, persistedBefore]);
    final statsAfter = _createClassStats([persistedAfter, created1, created2]);

    final stats = DiffClassStats.diff(before: statsBefore, after: statsAfter)!;

    expect(stats.heapClass, className);
    expect(stats.total.created.instanceCount, 2);
    expect(stats.total.deleted.instanceCount, 1);
    expect(stats.total.delta.instanceCount, 1);
  });

  test('$DiffClassStats calculates deletion as expected', () {
    final className = HeapClassName(className: 'myClass', library: 'library');

    final deleted = _createObject(className, 1, []);

    final statsBefore = _createClassStats([deleted]);

    final stats = DiffClassStats.diff(before: statsBefore, after: null)!;

    expect(stats.heapClass, className);
    expect(stats.total.created.instanceCount, 0);
    expect(stats.total.deleted.instanceCount, 1);
    expect(stats.total.delta.instanceCount, -1);
  });
}

SingleClassStats _createClassStats(List<AdaptedHeapObject> instances) {
  final indexes =
      Iterable<int>.generate(instances.length).map((i) => i + 1).toList();

  final objects = [
    _createObject(
      HeapClassName(className: 'root', library: 'lib'),
      0,
      indexes,
    ),
    ...instances,
  ];

  final heap = AdaptedHeapData(objects, rootIndex: 0);
  buildSpanningTree(heap);

  final result = SingleClassStats(instances.first.heapClass);
  for (var index in indexes) {
    result.countInstance(heap, index);
  }

  return result;
}

AdaptedHeapObject _createObject(
  HeapClassName className,
  int code,
  List<int> references,
) =>
    AdaptedHeapObject(
      code: code,
      references: references,
      heapClass: className,
      shallowSize: 1,
    );

AdaptedHeap _createSimplestHeap() => AdaptedHeap(
      AdaptedHeapData(
        [
          AdaptedHeapObject(
            code: 0,
            references: [],
            heapClass: HeapClassName(className: 'root', library: 'lib'),
            shallowSize: 1,
          )
        ],
        rootIndex: 0,
      ),
    );
