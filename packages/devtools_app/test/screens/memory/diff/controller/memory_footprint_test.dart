// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'dart:io';

import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  test(
    'heap snapshot processing creates reasonable memory footprint',
    () async {
      final snapshots = <String, HeapData>{};

      final before = ProcessInfo.currentRss;
      for (final t in goldenHeapTests) {
        snapshots[t.fileName] = HeapData(
          await t.loadHeap(),
          created: DateTime.now(),
        );
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
    // TODO(dantup): Understand why this fails on Windows. The delta is smaller
    //  than expected.
    //
    //    Expected: a value greater than <322122547.2>
    //    Actual: <320659456>
    //     Which: is not a value greater than <322122547.2>
    skip: Platform.isWindows,
  );
}
