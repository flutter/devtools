// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:devtools_app/src/shared/memory/heap_graph_loader.dart';
import 'package:vm_service/vm_service.dart';

const _dataDir = 'test/test_infra/test_data/memory/heap/';

class GoldenHeapTest {
  GoldenHeapTest({
    required this.fileName,
    required this.appClassName,
  });

  final String fileName;
  final String appClassName;

  Future<HeapSnapshotGraph> loadHeap() async {
    final (graph, _) =
        await HeapGraphLoaderFile.fromPath('$_dataDir$fileName').load();
    return graph;
  }
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
