// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../../test_infra/test_data/memory/heap/heap_graph_mock.dart';

void main() {
  for (var t in _sizeTests) {
    test('has expected root and unreachable sizes, ${t.name}.', () async {
      final heap = await HeapData.calculate(
        t.heap,
        DateTime.now(),
      );

      expect(
        heap.retainedSizes![HeapData.rootIndex],
        equals(t.rootRetainedSize),
      );

      var actualUnreachableSize = 0;
      for (int i = 0; i < t.heap.objects.length; i++) {
        final object = t.heap.objects[i];
        if (!heap.isReachable(i)) {
          actualUnreachableSize += object.shallowSize;
        }
      }
      expect(actualUnreachableSize, equals(t.unreachableSize));
    });
  }
}

final _sizeTests = [
  // Heaps without unreachable objects:
  _SizeTest(
    name: 'Just root',
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [],
        },
      ),
    rootRetainedSize: 1,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Two objects heap',
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2],
          2: [],
        },
      ),
    rootRetainedSize: 2,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Four objects heap',
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2, 3, 4],
          2: [],
          3: [],
          4: [],
        },
      ),
    rootRetainedSize: 4,
    unreachableSize: 0,
  ),

  // Heaps with unreachable objects:

  _SizeTest(
    name: 'One unreachable object heap',
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [],
          2: [],
        },
      ),
    rootRetainedSize: 1,
    unreachableSize: 1,
  ),
  _SizeTest(
    name: 'Many unreachable objects heap',
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          // Reachable:
          1: [2, 3, 4],
          2: [],
          3: [],
          4: [],

          // Unreachable:
          5: [6, 7, 8],
          6: [],
          7: [],
          8: [],
        },
      ),
    rootRetainedSize: 4,
    unreachableSize: 4,
  ),

  // // Heaps with weak objects:
  // _SizeTest(
  //   name: 'One weak object heap',
  //   //  0
  //   //  | \
  //   //  1w 2
  //   //  |
  //   //  3
  //   heap: _heapData(
  //     [
  //       _createOneByteObject(0, [1, 2]),
  //       _createOneByteWeakObject(1, [3]),
  //       _createOneByteObject(2, []),
  //       _createOneByteObject(3, []),
  //     ],
  //   ),
  //   rootRetainedSize: 3,
  //   unreachableSize: 1,
  // ),
  // _SizeTest(
  //   name: 'Two weak objects heap',
  //   //  0
  //   //  | \
  //   //  1w 2w
  //   //  |   \
  //   //  3   4
  //   heap: _heapData(
  //     [
  //       _createOneByteObject(0, [1, 2]),
  //       _createOneByteWeakObject(1, [3]),
  //       _createOneByteWeakObject(2, [4]),
  //       _createOneByteObject(3, []),
  //       _createOneByteObject(4, []),
  //     ],
  //   ),
  //   rootRetainedSize: 3,
  //   unreachableSize: 2,
  // ),

  // // Non-tree heaps.
  // _SizeTest(
  //   name: 'Diamond',
  //   //  |\
  //   //  \|
  //   heap: _heapData(
  //     [
  //       _createOneByteObject(0, [1, 2]),
  //       _createOneByteObject(1, [3]),
  //       _createOneByteObject(2, [3]),
  //       _createOneByteObject(3, []),
  //     ],
  //   ),
  //   rootRetainedSize: 4,
  //   unreachableSize: 0,
  // ),
  // _SizeTest(
  //   name: 'Hanged diamond',
  //   //  \
  //   //  |\
  //   //  \|
  //   heap: _heapData(
  //     [
  //       _createOneByteObject(0, [1]),
  //       _createOneByteObject(1, [2, 3]),
  //       _createOneByteObject(2, [4]),
  //       _createOneByteObject(3, [4]),
  //       _createOneByteObject(4, []),
  //     ],
  //   ),
  //   rootRetainedSize: 5,
  //   unreachableSize: 0,
  // ),
  // _SizeTest(
  //   name: 'Hanged weak diamond',
  //   //  \
  //   //  |\
  //   //  \|
  //   heap: _heapData(
  //     [
  //       _createOneByteObject(0, [1]),
  //       _createOneByteObject(1, [2, 3]),
  //       _createOneByteWeakObject(2, [4]),
  //       _createOneByteObject(3, [4]),
  //       _createOneByteObject(4, []),
  //     ],
  //   ),
  //   rootRetainedSize: 5,
  //   unreachableSize: 0,
  // ),
  // _SizeTest(
  //   name: 'Hanged very weak diamond',
  //   //  \
  //   //  |\
  //   //  \|
  //   heap: _heapData(
  //     [
  //       _createOneByteObject(0, [1]),
  //       _createOneByteObject(1, [2, 3]),
  //       _createOneByteWeakObject(2, [4]),
  //       _createOneByteWeakObject(3, [4]),
  //       _createOneByteObject(4, []),
  //     ],
  //   ),
  //   rootRetainedSize: 4,
  //   unreachableSize: 1,
  // ),
];

class _SizeTest {
  _SizeTest({
    required this.name,
    required this.heap,
    required this.rootRetainedSize,
    required this.unreachableSize,
  });

  final HeapSnapshotGraph heap;
  final String name;
  final int rootRetainedSize;
  final int unreachableSize;
}

// MockAdaptedHeapObject _createOneByteWeakObject(
//   int codeAndIndex,
//   List<int> references,
// ) {
//   final result = MockAdaptedHeapObject(
//     code: codeAndIndex,
//     outRefs: references.toSet(),
//     heapClass: HeapClassName.fromPath(
//       className: '_WeakProperty',
//       library: 'dart.core',
//     ),
//     shallowSize: 1,
//   );
//   assert(result.heapClass.isWeakEntry, isTrue);
//   return result;
// }

