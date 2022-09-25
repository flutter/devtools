// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/controller/heap_diff.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/heap.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      '$HeapDiffStore does not create new $DiffHeapClasses for the same couple',
      () {
    final heap1 = _createHeap();
    final heap2 = _createHeap();

    expect(heap1 == heap2, false);

    final store = HeapDiffStore();

    final couple1 = identityHashCode(store.compare(heap1, heap2));
    final couple2 = identityHashCode(store.compare(heap1, heap2));
    final couple3 = identityHashCode(store.compare(heap2, heap1));

    expect(couple1, couple2);
    expect(couple1, couple3);
  });
}

AdaptedHeap _createHeap() => AdaptedHeap(
      AdaptedHeapData(
        [
          AdaptedHeapObject(
            code: 0,
            references: [],
            heapClass:
                const HeapClassName(className: 'className', library: 'library'),
            shallowSize: 1,
          )
        ],
        rootIndex: 0,
      ),
    );
