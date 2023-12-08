// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Note: this test was modeled after the example test from Flutter Gallery:
// https://github.com/flutter/gallery/blob/master/test_benchmarks/benchmarks_test.dart

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:test/test.dart';
import 'package:web_benchmarks/server.dart';

import 'test_infra/common.dart';
import 'test_infra/project_root_directory.dart';

final metricList = <String>[
  'preroll_frame',
  'apply_frame',
  'drawFrameDuration',
];

final valueList = <String>[
  'average',
  'outlierAverage',
  'outlierRatio',
  'noise',
];

/// Tests that the DevTools web benchmarks are run and reported correctly.
void main() {
  test(
    'Can run web benchmarks',
    () async {
      await _runBenchmarks();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );


  // TODO(kenz): add tests that verify performance meets some expected threshold
}

Future<void> _runBenchmarks({bool useWasm = false}) async {
  stdout.writeln('Starting web benchmark tests ...');
  final taskResult = await serveWebBenchmark(
    benchmarkAppDirectory: projectRootDirectory(),
    entryPoint: 'benchmark/test_infra/client.dart',
    compilationOptions: CompilationOptions(useWasm: useWasm),
    treeShakeIcons: false,
    initialPage: benchmarkInitialPage,
  );
  stdout.writeln('Web benchmark tests finished.');

  expect(
    taskResult.scores.keys,
    hasLength(DevToolsBenchmark.values.length),
  );

  for (final benchmarkName in DevToolsBenchmark.values.map((e) => e.id)) {
    expect(
      taskResult.scores[benchmarkName],
      hasLength(metricList.length * valueList.length + 1),
    );

    for (final metricName in metricList) {
      for (final valueName in valueList) {
        expect(
          taskResult.scores[benchmarkName]?.where(
            (score) => score.metric == '$metricName.$valueName',
          ),
          hasLength(1),
        );
      }
    }

    expect(
      taskResult.scores[benchmarkName]?.where(
        (score) => score.metric == 'totalUiFrame.average',
      ),
      hasLength(1),
    );
  }

  expect(
    const JsonEncoder.withIndent('  ').convert(taskResult.toJson()),
    isA<String>(),
  );
}
