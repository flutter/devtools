// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/classes.dart';
import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/memory/heap/heap_graph_fakes.dart';

class _ClassSizeTest {
  _ClassSizeTest({
    required this.name,
    required this.heap,
    required this.expectedClassARetainedSize,
  });

  final FakeHeapSnapshotGraph heap;
  final String name;
  final int expectedClassARetainedSize;
}

final _root = HeapClassName.fromPath(className: 'Root', library: 'l');
final _classA = HeapClassName.fromPath(className: 'A', library: 'l');
final _classB = HeapClassName.fromPath(className: 'B', library: 'l');

final _classSizeTests = <_ClassSizeTest>[
  _ClassSizeTest(
    name: 'separate',
    heap: FakeHeapSnapshotGraph()
      ..setObjects(
        {
          1: [2, 3, 4],
          2: [],
          3: [],
          4: [],
        },
        classes: {
          1: _root,
          2: _classA,
          3: _classA,
          4: _classA,
        },
      ),
    expectedClassARetainedSize: 3,
  ),
  _ClassSizeTest(
    name: 'linked',
    heap: FakeHeapSnapshotGraph()
      ..setObjects(
        {
          1: [2],
          2: [3],
          3: [4],
          4: [],
        },
        classes: {
          1: _root,
          2: _classA,
          3: _classA,
          4: _classA,
        },
      ),
    expectedClassARetainedSize: 3,
  ),
  _ClassSizeTest(
    name: 'full graph',
    heap: FakeHeapSnapshotGraph()
      ..setObjects(
        {
          1: [2],
          2: [3, 4],
          3: [2, 4],
          4: [2, 3],
        },
        classes: {
          1: _root,
          2: _classA,
          3: _classA,
          4: _classA,
        },
      ),
    expectedClassARetainedSize: 3,
  ),
  _ClassSizeTest(
    name: 'with global B',
    heap: FakeHeapSnapshotGraph()
      ..setObjects(
        {
          1: [2],
          2: [3, 5],
          3: [4, 5],
          4: [2, 3],
          5: [],
        },
        classes: {
          1: _root,
          2: _classA,
          3: _classA,
          4: _classA,
          5: _classB,
        },
      ),
    expectedClassARetainedSize: 4,
  ),
];

void main() {
  for (final t in _classSizeTests) {
    test(
      '$SingleClassData does not double-count self-referenced classes, ${t.name}.',
      () async {
        final heapData = await HeapData.calculate(t.heap, DateTime.now());

        final classes = heapData.classes!;
        final classData = classes.byName(_classA)!;

        expect(
          classData.objects.retainedSize,
          t.expectedClassARetainedSize,
          reason: t.name,
        );
      },
    );
  }
}
