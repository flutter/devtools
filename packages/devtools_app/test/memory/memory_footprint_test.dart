// // Copyright 2023 The Chromium Authors. All rights reserved.
// // Use of this source code is governed by a BSD-style license that can be
// // found in the LICENSE file.

// @TestOn('vm')

// import 'dart:io';

// import 'package:devtools_app/src/screens/memory/shared/heap/heap.dart';
// import 'package:flutter_test/flutter_test.dart';

// import '../test_infra/test_data/memory/heap/heap_data.dart';

// void main() {
//   test('memory footprint', () async {
//     final snapshots = <String, AdaptedHeap>{};

//     final before = ProcessInfo.currentRss;
//     for (var t in goldenHeapTests) {
//       snapshots[t.fileName] = await AdaptedHeap.create(await t.loadHeap());
//     }

//     final after = ProcessInfo.currentRss;
//     final delta = after - before;

//     double gbToBytes(double gb) => gb * (1024 * 1024 * 1024);

//     final lowerThreshold = gbToBytes(0.85);
//     final upperThreshold = gbToBytes(1.08);

//     // Both thresholds are tested, because we want to lower the values
//     // in case of optimization.
//     expect(delta, greaterThan(lowerThreshold));
//     expect(delta, lessThan(upperThreshold));
//   });
// }
