// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/class_name.dart';
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
  _HeapPathTest('empty', HeapPath([]), isRetainedBySameClass: false),
];

void main() {
  test('$AdaptedHeapData serializes.', () {
    final json = AdaptedHeapData(
      [
        AdaptedHeapObject(
          code: 1,
          references: [3, 4, 5],
          heapClass: HeapClassName(
            className: 'class',
            library: 'library',
          ),
          shallowSize: 1,
        )
      ],
      rootIndex: 0,
      created: DateTime(2000),
    ).toJson();

    expect(json, AdaptedHeapData.fromJson(json).toJson());
  });

  for (final t in _heapPathTests) {
    test(
      '$HeapPath.isRetainedBySameClass returns expected result for ${t.name}',
      () {
        expect(t.heapPath.isRetainedBySameClass, t.isRetainedBySameClass);
      },
    );
  }
}
