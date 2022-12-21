// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';

import '../leaks/leaks_data.dart';

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

  static HeapLoader _loaderFromFile(String fileName) => () async {
        final json = jsonDecode(await File(fileName).readAsString());
        return AdaptedHeapData.fromJson(json);
      };
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
  ..._heapsFromLeakTests(),
];

Iterable<GoldenHeapTest> _heapsFromLeakTests() => goldenLeakTests.map(
      (t) => GoldenHeapTest(
        heapLoader: () async => (await t.task()).heap,
        name: t.name,
        appClassName: t.appClassName,
      ),
    );
