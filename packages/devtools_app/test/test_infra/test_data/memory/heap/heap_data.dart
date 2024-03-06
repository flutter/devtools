// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_app/src/shared/memory/heap_object.dart';

const _dataDir = 'test/test_infra/test_data/memory/heap/';

typedef HeapLoader = Future<AdaptedHeapData> Function();

class GoldenHeapTest {
  GoldenHeapTest({
    required this.fileName,
    required this.appClassName,
  });

  final String fileName;
  final String appClassName;

  /// Loads the heap data from a file.
  ///
  /// Format is format used by [NativeRuntime.writeHeapSnapshotToFile].
  Future<AdaptedHeapData> loadHeap() => heapFromFile('$_dataDir$fileName');
}

List<GoldenHeapTest> goldenHeapTests = <GoldenHeapTest>[
  GoldenHeapTest(
    fileName: 'counter_snapshot1',
    appClassName: 'MyApp',
  ),
  GoldenHeapTest(
    fileName: 'counter_snapshot2',
    appClassName: 'MyApp',
  ),
  GoldenHeapTest(
    fileName: 'counter_snapshot3',
    appClassName: 'MyApp',
  ),
  GoldenHeapTest(
    fileName: 'counter_snapshot4',
    appClassName: 'MyApp',
  ),
];

Future<AdaptedHeapData> heapFromFile(
  String fileName,
) async {
  final file = File(fileName);
  final bytes = await file.readAsBytes();
  return AdaptedHeapData.fromBytes(bytes);
}
