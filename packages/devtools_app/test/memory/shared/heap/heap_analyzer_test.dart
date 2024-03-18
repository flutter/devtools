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

  // Heaps with weak objects:
  _SizeTest(
    name: 'One weak object heap',
    //  1
    //  | \
    //  2w 3
    //  |
    //  4
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2, 3],
        },
      )
      ..addObjects(
        {
          2: [4],
        },
        weak: true,
      )
      ..addObjects(
        {
          3: [],
          4: [],
        },
      ),
    rootRetainedSize: 3,
    unreachableSize: 1,
  ),
  _SizeTest(
    name: 'Two weak objects heap',
    //  1
    //  | \
    //  2w 3w
    //  |   \
    //  4   5
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2, 3],
        },
      )
      ..addObjects(
        {
          2: [4],
          3: [5],
        },
        weak: true,
      )
      ..addObjects(
        {
          4: [],
          5: [],
        },
      ),
    rootRetainedSize: 3,
    unreachableSize: 2,
  ),

  // Non-tree heaps.
  _SizeTest(
    name: 'Diamond',
    //  |\
    //  \|
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2, 3],
          2: [4],
          3: [4],
          4: [],
        },
      ),
    rootRetainedSize: 4,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Hanged diamond',
    //  \
    //  |\
    //  \|
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2],
          2: [3, 4],
          3: [5],
          4: [5],
          5: [],
        },
      ),
    rootRetainedSize: 5,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Hanged weak diamond',
    //  \
    //  |\
    //  \|
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2],
          2: [3, 4],
        },
      )
      ..addObjects(
        {
          3: [5],
        },
        weak: true,
      )
      ..addObjects(
        {
          4: [5],
          5: [],
        },
      ),
    rootRetainedSize: 5,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Hanged very weak diamond',
    //  \
    //  |\
    //  \|
    heap: HeapSnapshotGraphMock()
      ..setObjects(
        {
          1: [2],
          2: [3, 4],
        },
      )
      ..addObjects(
        {
          3: [5],
          4: [5],
        },
        weak: true,
      )
      ..addObjects(
        {
          5: [],
        },
      ),
    rootRetainedSize: 4,
    unreachableSize: 1,
  ),
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
