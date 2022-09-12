// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';

import '../leaks/leaks_data.dart';

const _dataDir = 'test/test_data/memory/heap/';

typedef HeapLoader = Future<AdaptedHeap> Function();

class GoldenHeapTest {
  GoldenHeapTest.fromFile({
    required this.name,
    required this.appClassName,
  }) : heapLoader = _heapFromFile(name);

  GoldenHeapTest.fromLeaksTask({
    required NotGCedAnalyzerTask task,
    required this.name,
    required this.appClassName,
  }) : heapLoader = _heapFromTask(task);

  final String name;
  final String appClassName;
  final HeapLoader heapLoader;

  static HeapLoader _heapFromFile(String name) => () async {
        final path = '$_dataDir$name.json';
        final json = jsonDecode(await File(path).readAsString());
        return AdaptedHeap.fromJson(json);
      };

  static HeapLoader _heapFromTask(NotGCedAnalyzerTask task) =>
      () async => task.heap;
}

Future<Iterable<GoldenHeapTest>> goldenHeapTests() async => <GoldenHeapTest>[
      GoldenHeapTest.fromFile(
        name: 'counter_snapshot1',
        appClassName: 'MyApp',
      ),
      GoldenHeapTest.fromFile(
        name: 'counter_snapshot2',
        appClassName: 'MyApp',
      ),
      GoldenHeapTest.fromFile(
        name: 'counter_snapshot3',
        appClassName: 'MyApp',
      ),
      GoldenHeapTest.fromFile(
        name: 'counter_snapshot4',
        appClassName: 'MyApp',
      ),
      ...await _heapTestsFromLeakTests(),
    ];

Future<Iterable<GoldenHeapTest>> _heapTestsFromLeakTests() async => Future.wait(
      goldenLeakTests.map(
        (t) async => GoldenHeapTest.fromLeaksTask(
          task: await t.task(),
          name: t.name,
          appClassName: t.appClassName,
        ),
      ),
    );
