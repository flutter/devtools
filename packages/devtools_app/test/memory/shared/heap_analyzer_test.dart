// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/heap_analyzer.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_data/memory/heap/heap_data.dart';

void main() {
  for (var t in heapTests) {
    group(t.name, () {
      late NotGCedAnalyzerTask task;

      setUp(() async {
        task = await t.task();
      });

      test('has many objects and roots.', () {
        expect(task.heap.objects.length, greaterThan(1000));
        expect(
          task.heap.objects[task.heap.rootIndex].references.length,
          greaterThan(1000),
          reason: t.name,
        );
      });

      test('has exactly one object of type ${t.appClassName}.', () {
        final appObjects =
            task.heap.objects.where((o) => o.klass == t.appClassName);
        expect(appObjects, hasLength(1), reason: t.name);
      });

      test('has path to the object of type ${t.appClassName}.', () async {
        buildSpanningTree(task.heap);
        final appObject =
            task.heap.objects.where((o) => o.klass == t.appClassName).first;
        expect(appObject.retainer, isNotNull, reason: t.name);
      });
    });
  }

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
  _SizeTest(
    name: 'One object heap',
    heap: AdaptedHeap(
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
    heap: AdaptedHeap(
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
    heap: AdaptedHeap(
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
  _SizeTest(
    name: 'One unreachable object heap',
    heap: AdaptedHeap(
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
    heap: AdaptedHeap(
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
];

class _SizeTest {
  _SizeTest({
    required this.name,
    required this.heap,
    required this.rootRetainedSize,
    required this.unreachableSize,
  }) : assert(_assertHeapIndexIsCode(heap));

  /// For convenience of testing each each heap object has code equal to the
  /// index in array.
  final AdaptedHeap heap;

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
      klass: '',
      library: '',
      shallowSize: 1,
    );

bool _assertHeapIndexIsCode(AdaptedHeap heap) => heap.objects
    .asMap()
    .entries
    .every((entry) => entry.key == entry.value.code);
