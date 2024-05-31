// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  test(
    'heap snapshot processing creates reasonable memory footprint',
    () async {
      final snapshots = <String, HeapData>{};

      final before = ProcessInfo.currentRss;
      for (final t in goldenHeapTests) {
        snapshots[t.fileName] =
            HeapData(await t.loadHeap(), created: DateTime.now());
        await snapshots[t.fileName]!.calculate;
      }

      final after = ProcessInfo.currentRss;
      final delta = after - before;

      double gbToBytes(double gb) => gb * (1024 * 1024 * 1024);

      final lowerThreshold = gbToBytes(0.3);
      final upperThreshold = gbToBytes(0.4);

      // Both thresholds are tested, because we want to lower the values
      // in case of optimization.
      expect(delta, greaterThan(lowerThreshold));
      expect(delta, lessThan(upperThreshold));
    },
  );
}
