// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/heap/heap_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_data/memory/heap/heap_data.dart';

void main() async {
  for (var t in await goldenHeapTests()) {
    group(t.name, () {
      late AdaptedHeap heap;

      setUp(() async {
        heap = await t.heapLoader();
      });

      test('has many objects and roots.', () {
        expect(heap.objects.length, greaterThan(1000));
        expect(
          heap.objects[heap.rootIndex].references.length,
          greaterThan(1000),
          reason: t.name,
        );
      });

      test('has exactly one object of type ${t.appClassName}.', () {
        final appObjects =
            heap.objects.where((o) => o.className == t.appClassName);
        expect(appObjects, hasLength(1), reason: t.name);
      });

      test('has path to the object of type ${t.appClassName}.', () async {
        buildSpanningTree(heap);
        final appObject =
            heap.objects.where((o) => o.className == t.appClassName).first;
        expect(appObject.retainer, isNotNull, reason: t.name);
      });
    });
  }
}
