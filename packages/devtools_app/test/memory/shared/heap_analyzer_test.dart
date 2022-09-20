// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/spanning_tree.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/heap_analyzer.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (var t in _sizeTests) {
    group(t.name, () {
      test('has expected root and unreachable sizes.', () {
        buildSpanningTree(t.heap);
        expect(t.heap.root.retainedSize, equals(t.rootRetainedSize));

        var actualUnreachableSize = 0;
        for (var object in t.heap.objects) {
          if (object.retainer == null) {
            expect(object.retainedSize, isNull);
            actualUnreachableSize += object.shallowSize;
          }
        }
        expect(actualUnreachableSize, equals(t.unreachableSize));
      });
    });
  }
}

final _sizeTests = [
  // Heaps without unreachable objects:

  _SizeTest(
    name: 'One object heap',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 1,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Two objects heap',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1]),
        _createOneByteObject(1, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 2,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Four objects heap',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1, 2, 3]),
        _createOneByteObject(1, []),
        _createOneByteObject(2, []),
        _createOneByteObject(3, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 4,
    unreachableSize: 0,
  ),

  // Heaps with unreachable objects:

  _SizeTest(
    name: 'One unreachable object heap',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, []),
        _createOneByteObject(1, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 1,
    unreachableSize: 1,
  ),
  _SizeTest(
    name: 'Many unreachable objects heap',
    heap: AdaptedHeapData(
      [
        // Reachable:
        _createOneByteObject(0, [1, 2, 3]),
        _createOneByteObject(1, []),
        _createOneByteObject(2, []),
        _createOneByteObject(3, []),

        // Unreachable:
        _createOneByteObject(4, [5, 6, 7]),
        _createOneByteObject(5, []),
        _createOneByteObject(6, []),
        _createOneByteObject(7, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 4,
    unreachableSize: 4,
  ),

  // Heaps with weak objects:
  _SizeTest(
    name: 'One weak object heap',
    //  0
    //  | \
    //  1w 2
    //  |
    //  3
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1, 2]),
        _createOneByteWeakObject(1, [3]),
        _createOneByteObject(2, []),
        _createOneByteObject(3, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 3,
    unreachableSize: 1,
  ),
  _SizeTest(
    name: 'Two weak objects heap',
    //  0
    //  | \
    //  1w 2w
    //  |   \
    //  3   4
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1, 2]),
        _createOneByteWeakObject(1, [3]),
        _createOneByteWeakObject(2, [4]),
        _createOneByteObject(3, []),
        _createOneByteObject(4, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 3,
    unreachableSize: 2,
  ),

  // Non-tree heaps.
  _SizeTest(
    name: 'Diamond',
    //  |\
    //  \|
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1, 2]),
        _createOneByteObject(1, [3]),
        _createOneByteObject(2, [3]),
        _createOneByteObject(3, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 4,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Hanged diamond',
    //  \
    //  |\
    //  \|
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1]),
        _createOneByteObject(1, [2, 3]),
        _createOneByteObject(2, [4]),
        _createOneByteObject(3, [4]),
        _createOneByteObject(4, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 5,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Hanged weak diamond',
    //  \
    //  |\
    //  \|
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1]),
        _createOneByteObject(1, [2, 3]),
        _createOneByteWeakObject(2, [4]),
        _createOneByteObject(3, [4]),
        _createOneByteObject(4, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 5,
    unreachableSize: 0,
  ),
  _SizeTest(
    name: 'Hanged very weak diamond',
    //  \
    //  |\
    //  \|
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1]),
        _createOneByteObject(1, [2, 3]),
        _createOneByteWeakObject(2, [4]),
        _createOneByteWeakObject(3, [4]),
        _createOneByteObject(4, []),
      ],
      rootIndex: 0,
    ),
    rootRetainedSize: 4,
    unreachableSize: 1,
  ),
];

class _SizeTest {
  _SizeTest({
    required this.name,
    required this.heap,

    /// Retained size of the root.
    required this.rootRetainedSize,

    /// Total size of all unreachable objects.
    required this.unreachableSize,
  }) : assert(_assertHeapIndexIsCode(heap));

  /// For convenience of testing each heap object has code equal to the
  /// index in array.
  final AdaptedHeapData heap;

  final String name;

  final int rootRetainedSize;

  final int unreachableSize;
}

AdaptedHeapObject _createOneByteObject(
  int codeAndIndex,
  List<int> references,
) =>
    AdaptedHeapObject(
      code: codeAndIndex,
      references: references,
      heapClass: HeapClass(
        className: 'MyClass',
        library: 'my_lib',
      ),
      shallowSize: 1,
    );

AdaptedHeapObject _createOneByteWeakObject(
  int codeAndIndex,
  List<int> references,
) {
  final result = AdaptedHeapObject(
    code: codeAndIndex,
    references: references,
    heapClass: HeapClass(
      className: '_WeakProperty',
      library: 'dart.core',
    ),
    shallowSize: 1,
  );
  assert(result.heapClass.isWeakEntry, isTrue);
  return result;
}

bool _assertHeapIndexIsCode(AdaptedHeapData heap) => heap.objects
    .asMap()
    .entries
    .every((entry) => entry.key == entry.value.code);
