// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/adapted_heap_data.dart';
import 'package:devtools_app/src/shared/memory/adapted_heap_object.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:flutter_test/flutter_test.dart';

class _HeapPathTest {
  _HeapPathTest(
    this.name,
    this.heapPath, {
    required this.isRetainedBySameClass,
  });

  final String name;
  final HeapPath heapPath;
  final bool isRetainedBySameClass;
}

final _heapPathTests = <_HeapPathTest>[
  _HeapPathTest(
    'empty',
    HeapPath([]),
    isRetainedBySameClass: false,
  ),
  _HeapPathTest(
    'one item',
    HeapPath([_objectForClass('myLib', 'myClass')]),
    isRetainedBySameClass: false,
  ),
  _HeapPathTest(
    'two different',
    HeapPath([
      _objectForClass('myLib1', 'myClass'),
      _objectForClass('myLib2', 'myClass'),
    ]),
    isRetainedBySameClass: false,
  ),
  _HeapPathTest(
    'two identical',
    HeapPath([
      _objectForClass('myLib', 'myClass'),
      _objectForClass('myLib', 'myClass'),
    ]),
    isRetainedBySameClass: true,
  ),
  _HeapPathTest(
    'three identical',
    HeapPath([
      _objectForClass('myLib', 'myClass'),
      _objectForClass('myLib', 'myClass'),
      _objectForClass('myLib', 'myClass'),
    ]),
    isRetainedBySameClass: true,
  ),
];

void main() {
  test('$HeapPath.isRetainedBySameClass returns expected result for.', () {
    for (final t in _heapPathTests) {
      expect(
        t.heapPath.isRetainedBySameClass,
        t.isRetainedBySameClass,
        reason: t.name,
      );
    }
  });
}

AdaptedHeapObject _objectForClass(String lib, String theClass) =>
    AdaptedHeapObject(
      code: 1,
      outRefs: {},
      heapClass: HeapClassName.fromPath(className: theClass, library: lib),
      shallowSize: 1,
    );
