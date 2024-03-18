// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../../test_infra/test_data/memory/heap/heap_graph_mock.dart';

class _ClassSizeTest {
  _ClassSizeTest({
    required this.name,
    required this.heap,
    required this.expectedClassARetainedSize,
  });

  Future<void> initialize() async {}

  final HeapSnapshotGraph heap;
  final String name;
  final int expectedClassARetainedSize;
}

final _root = HeapClassName.fromPath(className: 'Root', library: 'l');
final _classA = HeapClassName.fromPath(className: 'A', library: 'l');
final _classB = HeapClassName.fromPath(className: 'B', library: 'l');

final _classSizeTests = <_ClassSizeTest>[
  _ClassSizeTest(
    name: 'separate',
    heap: HeapSnapshotGraphMock()
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
  // _ClassSizeTest(
  //   name: 'linked',
  //   heap: AdaptedHeapData(
  //     [
  //       _createOneByteObject(0, [1], _root),
  //       _createOneByteObject(1, [2], _classA),
  //       _createOneByteObject(2, [3], _classA),
  //       _createOneByteObject(3, [], _classA),
  //     ],
  //     rootIndex: 0,
  //   ),
  //   expectedClassARetainedSize: 3,
  // ),
  // _ClassSizeTest(
  //   name: 'full graph',
  //   heap: AdaptedHeapData(
  //     [
  //       _createOneByteObject(0, [1], _root),
  //       _createOneByteObject(1, [2, 3], _classA),
  //       _createOneByteObject(2, [3, 1], _classA),
  //       _createOneByteObject(3, [1, 2], _classA),
  //     ],
  //     rootIndex: 0,
  //   ),
  //   expectedClassARetainedSize: 3,
  // ),
  // _ClassSizeTest(
  //   name: 'with global B',
  //   heap: AdaptedHeapData(
  //     [
  //       _createOneByteObject(0, [1], _root),
  //       _createOneByteObject(1, [2, 4], _classA),
  //       _createOneByteObject(2, [3, 4], _classA),
  //       _createOneByteObject(3, [4], _classA),
  //       _createOneByteObject(4, [], _classB),
  //     ],
  //     rootIndex: 0,
  //   ),
  //   expectedClassARetainedSize: 4,
  // ),
];

void main() {
  setUp(() async {
    for (final t in _classSizeTests) {
      await t.initialize();
    }
  });

  // test('$SingleClassStats_ does not double-count self-referenced classes.', () {
  //   for (final t in _classSizeTests) {
  //     final classes = SingleClassStats_(heapClass: _classA);
  //     for (final o in t.heap.objects) {
  //       if (o.heapClass == _classA) classes.countInstance(t.heap, o.code);
  //     }
  //     expect(
  //       classes.objects.retainedSize,
  //       t.expectedClassARetainedSize,
  //       reason: t.name,
  //     );
  //   }
  // });
}
