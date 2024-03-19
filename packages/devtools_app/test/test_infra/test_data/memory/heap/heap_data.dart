// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/heap_graph_loader.dart';
import 'package:vm_service/vm_service.dart';

const _dataDir = 'test/test_infra/test_data/memory/heap/';

abstract class HeapTest {
  HeapTest({required this.appClassName});

  /// The name of the class that represents the app.
  final String appClassName;

  Future<HeapSnapshotGraph> loadHeap();
}

class GoldenHeapTest extends HeapTest {
  GoldenHeapTest({
    required super.appClassName,
    required this.fileName,
  });

  final String fileName;

  @override
  Future<HeapSnapshotGraph> loadHeap() async {
    final (graph, _) =
        await HeapGraphLoaderFile.fromPath('$_dataDir$fileName').load();
    return graph;
  }
}

class MockedHeapTest extends HeapTest {
  MockedHeapTest({
    required super.appClassName,
  });

  @override
  Future<HeapSnapshotGraph> loadHeap() async {
    throw UnimplementedError();
  }
}

/// Provides test snapshots from pre-saved goldens.
class HeapGraphLoaderGoldens implements HeapGraphLoader {
  int _nextIndex = 0;

  @override
  Future<(HeapSnapshotGraph, DateTime)> load() async {
    // This delay is needed for UI to start showing the progress indicator.
    await Future.delayed(const Duration(milliseconds: 100));
    final result = await goldenHeapTests[_nextIndex].loadHeap();

    _nextIndex = (_nextIndex + 1) % goldenHeapTests.length;

    return (result, DateTime.now());
  }
}

/// Provides test snapshots, provided in constructor.
class HeapGraphLoaderProvided implements HeapGraphLoader {
  HeapGraphLoaderProvided(this.graphs) : assert(graphs.isNotEmpty);

  List<HeapSnapshotGraph> graphs;

  int _nextIndex = 0;

  @override
  Future<(HeapSnapshotGraph, DateTime)> load() async {
    // This delay is needed for UI to start showing the progress indicator.
    await Future.delayed(const Duration(milliseconds: 100));
    final result = graphs[_nextIndex];
    _nextIndex = (_nextIndex + 1) % goldenHeapTests.length;

    return (result, DateTime.now());
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
