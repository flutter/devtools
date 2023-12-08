// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Note: this test was modeled after the example test from Flutter Gallery:
// https://github.com/flutter/gallery/blob/master/test_benchmarks/benchmarks_test.dart

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:test/test.dart';
import 'package:web_benchmarks/server.dart';

import 'scripts/compare_benchmarks.dart';
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

  test(
    'Can compare web benchmarks',
    () {
      final benchmark1 = BenchmarkResults.parse(testBenchmarkResults1);
      final benchmark2 = BenchmarkResults.parse(testBenchmarkResults2);
      final comparison = compareBenchmarks(
        benchmark1,
        benchmark2,
        baselineSource: 'path/to/baseline',
      );
      expect(comparison, testBenchmarkComparison);
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

final testBenchmarkResults1 = {
  'foo': [
    {'metric': 'preroll_frame.average', 'value': 60.5},
    {'metric': 'preroll_frame.outlierAverage', 'value': 1400},
    {'metric': 'preroll_frame.outlierRatio', 'value': 20.2},
    {'metric': 'preroll_frame.noise', 'value': 0.85},
    {'metric': 'apply_frame.average', 'value': 80.0},
    {'metric': 'apply_frame.outlierAverage', 'value': 200.6},
    {'metric': 'apply_frame.outlierRatio', 'value': 2.5},
    {'metric': 'apply_frame.noise', 'value': 0.4},
    {'metric': 'drawFrameDuration.average', 'value': 2058.9},
    {'metric': 'drawFrameDuration.outlierAverage', 'value': 24000},
    {'metric': 'drawFrameDuration.outlierRatio', 'value': 12.05},
    {'metric': 'drawFrameDuration.noise', 'value': 0.34},
    {'metric': 'totalUiFrame.average', 'value': 4166},
  ],
  'bar': [
    {'metric': 'preroll_frame.average', 'value': 60.5},
    {'metric': 'preroll_frame.outlierAverage', 'value': 1400},
    {'metric': 'preroll_frame.outlierRatio', 'value': 20.2},
    {'metric': 'preroll_frame.noise', 'value': 0.85},
    {'metric': 'apply_frame.average', 'value': 80.0},
    {'metric': 'apply_frame.outlierAverage', 'value': 200.6},
    {'metric': 'apply_frame.outlierRatio', 'value': 2.5},
    {'metric': 'apply_frame.noise', 'value': 0.4},
    {'metric': 'drawFrameDuration.average', 'value': 2058.9},
    {'metric': 'drawFrameDuration.outlierAverage', 'value': 24000},
    {'metric': 'drawFrameDuration.outlierRatio', 'value': 12.05},
    {'metric': 'drawFrameDuration.noise', 'value': 0.34},
    {'metric': 'totalUiFrame.average', 'value': 4166},
  ],
};

final testBenchmarkResults2 = {
  'foo': [
    {'metric': 'preroll_frame.average', 'value': 65.5},
    {'metric': 'preroll_frame.outlierAverage', 'value': 1410},
    {'metric': 'preroll_frame.outlierRatio', 'value': 20.0},
    {'metric': 'preroll_frame.noise', 'value': 1.5},
    {'metric': 'apply_frame.average', 'value': 50.0},
    {'metric': 'apply_frame.outlierAverage', 'value': 100.0},
    {'metric': 'apply_frame.outlierRatio', 'value': 2.55},
    {'metric': 'apply_frame.noise', 'value': 0.9},
    {'metric': 'drawFrameDuration.average', 'value': 2000.0},
    {'metric': 'drawFrameDuration.outlierAverage', 'value': 20000},
    {'metric': 'drawFrameDuration.outlierRatio', 'value': 11.05},
    {'metric': 'drawFrameDuration.noise', 'value': 1.34},
    {'metric': 'totalUiFrame.average', 'value': 4150},
  ],
  'bar': [
    {'metric': 'preroll_frame.average', 'value': 65.5},
    {'metric': 'preroll_frame.outlierAverage', 'value': 1410},
    {'metric': 'preroll_frame.outlierRatio', 'value': 20.0},
    {'metric': 'preroll_frame.noise', 'value': 1.5},
    {'metric': 'apply_frame.average', 'value': 50.0},
    {'metric': 'apply_frame.outlierAverage', 'value': 100.0},
    {'metric': 'apply_frame.outlierRatio', 'value': 2.55},
    {'metric': 'apply_frame.noise', 'value': 0.9},
    {'metric': 'drawFrameDuration.average', 'value': 2000.0},
    {'metric': 'drawFrameDuration.outlierAverage', 'value': 20000},
    {'metric': 'drawFrameDuration.outlierRatio', 'value': 11.05},
    {'metric': 'drawFrameDuration.noise', 'value': 1.34},
    {'metric': 'totalUiFrame.average', 'value': 4150},
  ],
};

final testBenchmarkComparison = {
  'foo': [
    {'metric': 'preroll_frame.average', 'value': 65.5, 'delta': 5.0},
    {'metric': 'preroll_frame.outlierAverage', 'value': 1410.0, 'delta': 10.0},
    {
      'metric': 'preroll_frame.outlierRatio',
      'value': 20.0,
      'delta': -0.1999999999999993,
    },
    {'metric': 'preroll_frame.noise', 'value': 1.5, 'delta': 0.65},
    {'metric': 'apply_frame.average', 'value': 50.0, 'delta': -30.0},
    {'metric': 'apply_frame.outlierAverage', 'value': 100.0, 'delta': -100.6},
    {
      'metric': 'apply_frame.outlierRatio',
      'value': 2.55,
      'delta': 0.04999999999999982,
    },
    {'metric': 'apply_frame.noise', 'value': 0.9, 'delta': 0.5},
    {
      'metric': 'drawFrameDuration.average',
      'value': 2000.0,
      'delta': -58.90000000000009,
    },
    {
      'metric': 'drawFrameDuration.outlierAverage',
      'value': 20000.0,
      'delta': -4000.0,
    },
    {'metric': 'drawFrameDuration.outlierRatio', 'value': 11.05, 'delta': -1.0},
    {'metric': 'drawFrameDuration.noise', 'value': 1.34, 'delta': 1.0},
    {'metric': 'totalUiFrame.average', 'value': 4150.0, 'delta': -16.0},
  ],
  'bar': [
    {'metric': 'preroll_frame.average', 'value': 65.5, 'delta': 5.0},
    {'metric': 'preroll_frame.outlierAverage', 'value': 1410.0, 'delta': 10.0},
    {
      'metric': 'preroll_frame.outlierRatio',
      'value': 20.0,
      'delta': -0.1999999999999993,
    },
    {'metric': 'preroll_frame.noise', 'value': 1.5, 'delta': 0.65},
    {'metric': 'apply_frame.average', 'value': 50.0, 'delta': -30.0},
    {'metric': 'apply_frame.outlierAverage', 'value': 100.0, 'delta': -100.6},
    {
      'metric': 'apply_frame.outlierRatio',
      'value': 2.55,
      'delta': 0.04999999999999982,
    },
    {'metric': 'apply_frame.noise', 'value': 0.9, 'delta': 0.5},
    {
      'metric': 'drawFrameDuration.average',
      'value': 2000.0,
      'delta': -58.90000000000009,
    },
    {
      'metric': 'drawFrameDuration.outlierAverage',
      'value': 20000.0,
      'delta': -4000.0,
    },
    {'metric': 'drawFrameDuration.outlierRatio', 'value': 11.05, 'delta': -1.0},
    {'metric': 'drawFrameDuration.noise', 'value': 1.34, 'delta': 1.0},
    {'metric': 'totalUiFrame.average', 'value': 4150.0, 'delta': -16.0},
  ],
};
