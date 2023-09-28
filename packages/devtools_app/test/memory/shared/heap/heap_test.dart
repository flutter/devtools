// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/heap/heap.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/spanning_tree.dart';
import 'package:devtools_app/src/shared/memory/adapted_heap_data.dart';
import 'package:devtools_app/src/shared/memory/adapted_heap_object.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';

import 'package:flutter_test/flutter_test.dart';

class _ClassSizeTest {
  _ClassSizeTest({
    required this.name,
    required this.heap,
    required this.expectedClassARetainedSize,
  }) : assert(_assertHeapIndexIsCode(heap));

  Future<void> initialize() => calculateHeap(heap);

  final AdaptedHeapData heap;
  final String name;
  final int expectedClassARetainedSize;
}

final _root = HeapClassName.fromPath(className: 'Root', library: 'l');
final _classA = HeapClassName.fromPath(className: 'A', library: 'l');
final _classB = HeapClassName.fromPath(className: 'B', library: 'l');

final _classSizeTests = <_ClassSizeTest>[
  _ClassSizeTest(
    name: 'separate',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1, 2, 3], _root),
        _createOneByteObject(1, [], _classA),
        _createOneByteObject(2, [], _classA),
        _createOneByteObject(3, [], _classA),
      ],
      rootIndex: 0,
      isolateId: '',
    ),
    expectedClassARetainedSize: 3,
  ),
  _ClassSizeTest(
    name: 'linked',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1], _root),
        _createOneByteObject(1, [2], _classA),
        _createOneByteObject(2, [3], _classA),
        _createOneByteObject(3, [], _classA),
      ],
      rootIndex: 0,
      isolateId: '',
    ),
    expectedClassARetainedSize: 3,
  ),
  _ClassSizeTest(
    name: 'full graph',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1], _root),
        _createOneByteObject(1, [2, 3], _classA),
        _createOneByteObject(2, [3, 1], _classA),
        _createOneByteObject(3, [1, 2], _classA),
      ],
      rootIndex: 0,
      isolateId: '',
    ),
    expectedClassARetainedSize: 3,
  ),
  _ClassSizeTest(
    name: 'with global B',
    heap: AdaptedHeapData(
      [
        _createOneByteObject(0, [1], _root),
        _createOneByteObject(1, [2, 4], _classA),
        _createOneByteObject(2, [3, 4], _classA),
        _createOneByteObject(3, [4], _classA),
        _createOneByteObject(4, [], _classB),
      ],
      rootIndex: 0,
      isolateId: '',
    ),
    expectedClassARetainedSize: 4,
  ),
];

void main() {
  setUp(() async {
    for (final t in _classSizeTests) {
      await t.initialize();
    }
  });

  test('$SingleClassStats does not double-count self-referenced classes.', () {
    for (final t in _classSizeTests) {
      final classes = SingleClassStats(heapClass: _classA);
      for (final o in t.heap.objects) {
        if (o.heapClass == _classA) classes.countInstance(t.heap, o.code);
      }
      expect(
        classes.objects.retainedSize,
        t.expectedClassARetainedSize,
        reason: t.name,
      );
    }
  });
}

AdaptedHeapObject _createOneByteObject(
  int codeAndIndex,
  List<int> references,
  HeapClassName theClass,
) =>
    AdaptedHeapObject(
      code: codeAndIndex,
      outRefs: references.toSet(),
      heapClass: theClass,
      shallowSize: 1,
    );

/// For convenience of testing each heap object has code equal to the
/// index in array.
bool _assertHeapIndexIsCode(AdaptedHeapData heap) => heap.objects
    .asMap()
    .entries
    .every((entry) => entry.key == entry.value.code);
