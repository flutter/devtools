// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/widgets/class_details/paths.dart';
import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/scenes/memory/default.dart';

void main() {
  test('Many retaining paths do not jank UI.', () async {
    final heap = HeapData(
      await MemoryDefaultSceneHeaps.manyPaths(),
      created: DateTime.now(),
    );
    await heap.calculate;
    final data = heap.classes!.list
        .firstWhere((c) => c.className.className == 'TheData');

    expect(data.byPath.length, greaterThan(90));

    final stopWatch = Stopwatch()..start();
    RetainingPathTable.toPathDataList(data);
    final micros = stopWatch.elapsedMicroseconds;
    expect(micros, isPositive);
    expect(micros, lessThan(2000));
  });
}
