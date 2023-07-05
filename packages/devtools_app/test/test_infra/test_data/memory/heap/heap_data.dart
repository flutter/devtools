// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/adapted_heap_data.dart';

const _dataDir = 'test/test_infra/test_data/memory/heap/';

typedef HeapLoader = Future<AdaptedHeapData> Function();

class GoldenHeapTest {
  GoldenHeapTest({
    HeapLoader? heapLoader,
    required this.name,
    required this.appClassName,
  }) : loadHeap = heapLoader ?? _loaderFromFile('$_dataDir$name.json');

  final String name;
  final String appClassName;
  late HeapLoader loadHeap;

  /// Loads the heap data from a file.
  ///
  /// Format is format used by [NativeRuntime.writeHeapSnapshotToFile]
  static Future<AdaptedHeapData> _loadFromFile(String fileName) async {
    return AdaptedHeapData.fromFile(fileName, isolateId: 'test');
  }

  static HeapLoader _loaderFromFile(String fileName) =>
      () => _loadFromFile(fileName);
}

List<GoldenHeapTest> goldenHeapTests = <GoldenHeapTest>[
  GoldenHeapTest(
    name: 'counter_snapshot1',
    appClassName: 'MyApp',
  ),
  GoldenHeapTest(
    name: 'counter_snapshot2',
    appClassName: 'MyApp',
  ),
  GoldenHeapTest(
    name: 'counter_snapshot3',
    appClassName: 'MyApp',
  ),
  GoldenHeapTest(
    name: 'counter_snapshot4',
    appClassName: 'MyApp',
  ),
];
