// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/data/classes_diff.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/data/heap_diff_data.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/data/heap_diff_store.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/memory/heap/factories.dart';
import '../../../test_infra/test_data/memory/heap/heap_graph_mock.dart';

void main() {
  test(
    '$HeapDiffStore does not create new $HeapDiffData for the same couple',
    () async {
      final heap1 = await testHeapData();
      final heap2 = await testHeapData();

      expect(heap1 == heap2, false);

      final store = HeapDiffStore();

      final couple1 = identityHashCode(store.compare(heap1, heap2));
      final couple2 = identityHashCode(store.compare(heap1, heap2));
      final couple3 = identityHashCode(store.compare(heap2, heap1));

      expect(couple1, couple2);
      expect(couple1, couple3);
    },
  );

  test('$DiffClassData calculates mix of cases as expected', () async {
    final className =
        HeapClassName.fromPath(className: 'myClass', library: 'library');

    final graphBefore = HeapSnapshotGraphFake();
    final deleted = graphBefore.add(1);
    final persistedBefore = graphBefore.add(2);

    final graphAfter = HeapSnapshotGraphFake();
    final persistedAfter = graphAfter.add(2);
    final created1 = graphAfter.add(3);
    final created2 = graphAfter.add(4);

    final classBefore = testClassData(
      className,
      [deleted, persistedBefore],
      graphBefore,
    );
    final classAfter = testClassData(
      className,
      [persistedAfter, created1, created2],
      graphAfter,
    );

    final diff = DiffClassData.compare(
      before: classBefore,
      dataBefore: await testHeapData(graphBefore),
      after: classAfter,
      dataAfter: await testHeapData(graphAfter),
    )!;

    expect(diff.className, className);
    expect(diff.diff.created.instanceCount, 2);
    expect(diff.diff.deleted.instanceCount, 1);
    expect(diff.diff.delta.instanceCount, 1);
    expect(diff.diff.persisted.instanceCount, 1);
  });

  test('$DiffClassData calculates deletion as expected', () async {
    final className =
        HeapClassName.fromPath(className: 'myClass', library: 'library');

    final graphBefore = HeapSnapshotGraphFake();
    final deleted = graphBefore.add(1);

    final classBefore = testClassData(
      className,
      [deleted],
      graphBefore,
    );

    final diff = DiffClassData.compare(
      before: classBefore,
      dataBefore: await testHeapData(graphBefore),
      after: null,
      dataAfter: await testHeapData(),
    )!;

    expect(diff.className, className);
    expect(diff.diff.created.instanceCount, 0);
    expect(diff.diff.deleted.instanceCount, 1);
    expect(diff.diff.delta.instanceCount, -1);
    expect(diff.diff.persisted.instanceCount, 0);
  });
}
