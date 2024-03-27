// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:devtools_app/src/shared/memory/retaining_path.dart';
import 'package:devtools_app/src/shared/memory/simple_items.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  for (var t in goldenHeapTests) {
    group(t.fileName, () {
      late HeapData heap;
      late int appClassId;

      setUp(() async {
        PathFromRoot.resetSingletons();

        heap = await HeapData.calculate(await t.loadHeap(), DateTime.now());
        expect(PathFromRoot.debugUsage.stored, isPositive);
        expect(
          PathFromRoot.debugUsage.constructed,
          greaterThan(PathFromRoot.debugUsage.stored),
        );
        expect(PathFromRoot.debugUsage.stringified, 0);

        appClassId = findClassId(heap, t.appClassName);
      });

      test('has many objects and roots.', () {
        expect(heap.graph.objects.length, greaterThan(1000));
        expect(
          heap.graph.objects[heapRootIndex].references.length,
          greaterThan(1000),
          reason: t.fileName,
        );
      });

      test('has exactly one object of type ${t.appClassName}.', () {
        final appObjects =
            heap.graph.objects.where((o) => o.classId == appClassId);
        expect(appObjects, hasLength(1), reason: t.fileName);
      });

      test('has path to the object of type ${t.appClassName}.', () {
        final className =
            HeapClassName.fromHeapSnapshotClass(heap.graph.classes[appClassId]);

        final classData = heap.classes!.asMap()[className]!;
        expect(classData.byPath, isNotEmpty, reason: t.fileName);
      });
    });
  }
}

int findClassId(HeapData heap, String className) {
  return heap.graph.classes
      .firstWhere(
        (c) => c.name == className,
        orElse: () => throw StateError(
          'No class found with name $className.',
        ),
      )
      .classId;
}
