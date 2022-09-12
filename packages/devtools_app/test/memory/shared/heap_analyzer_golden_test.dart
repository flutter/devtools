// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/heap_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_data/memory/heap/heap_data.dart';

void main() {
  for (var t in goldenHeapTests) {
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
}
