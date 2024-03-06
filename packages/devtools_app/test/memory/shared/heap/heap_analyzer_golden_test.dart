// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/heap/spanning_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  for (var t in goldenHeapTests) {
    group(t.fileName, () {
      late AdaptedHeapData heap;

      setUp(() async {
        heap = await t.loadHeap();
      });

      test('has many objects and roots.', () {
        expect(heap.objects.length, greaterThan(1000));
        expect(
          heap.objects[heap.rootIndex].outRefs.length,
          greaterThan(1000),
          reason: t.fileName,
        );
      });

      test('has exactly one object of type ${t.appClassName}.', () {
        final appObjects =
            heap.objects.where((o) => o.heapClass.className == t.appClassName);
        expect(appObjects, hasLength(1), reason: t.fileName);
      });

      test('has path to the object of type ${t.appClassName}.', () async {
        await calculateHeap(heap);
        final appObject = heap.objects
            .where((o) => o.heapClass.className == t.appClassName)
            .first;
        expect(appObject.retainer, isNotNull, reason: t.fileName);
      });
    });
  }
}
