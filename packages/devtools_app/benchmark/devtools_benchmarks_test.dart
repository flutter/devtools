// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Note: this test was modeled after the example test from Flutter Gallery:
// https://github.com/flutter/gallery/blob/master/test_benchmarks/benchmarks_test.dart

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:web_benchmarks/metrics.dart';
import 'package:web_benchmarks/server.dart';

import 'test_infra/common.dart';
import 'test_infra/project_root_directory.dart';

const _isWasmScore = 'isWasm';

const _extraScores = [
  totalUiFrameAverage,
  _isWasmScore,
];

/// Tests that the DevTools web benchmarks are run and reported correctly.
void main() {
  for (final useWasm in [true, false]) {
    test(
      'Can run web benchmarks with ${useWasm ? 'WASM' : 'JS'}',
      () async {
        await _runBenchmarks(useWasm: useWasm);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

  // TODO(kenz): add tests that verify performance meets some expected threshold
}

Future<void> _runBenchmarks({bool useWasm = false}) async {
  stdout.writeln('Starting web benchmark tests ...');
  final taskResult = await serveWebBenchmark(
    benchmarkAppDirectory: projectRootDirectory(),
    entryPoint: generateBenchmarkEntryPoint(useWasm: useWasm),
    compilationOptions: useWasm
        ? const CompilationOptions.wasm()
        : const CompilationOptions.js(),
    treeShakeIcons: false,
    benchmarkPath: benchmarkPath(useWasm: useWasm),
  );
  stdout.writeln('Web benchmark tests finished.');

  expect(
    taskResult.scores.keys,
    hasLength(DevToolsBenchmark.values.length),
  );

  for (final benchmarkName in DevToolsBenchmark.values.map((e) => e.id)) {
    final expectedMetrics = expectedBenchmarkMetrics(useWasm: useWasm)
        .map((BenchmarkMetric metric) => metric.label)
        .toList();
    const expectedComputations = BenchmarkMetricComputation.values;
    final scores = taskResult.scores[benchmarkName] ?? [];
    expect(
      scores,
      hasLength(
        expectedMetrics.length * expectedComputations.length +
            _extraScores.length,
      ),
    );

    for (final metricName in expectedMetrics) {
      for (final computation in expectedComputations) {
        expect(
          scores.where(
            (score) => score.metric == '$metricName.${computation.name}',
          ),
          hasLength(1),
        );
      }
    }

    expect(
      scores.where((score) => score.metric == totalUiFrameAverage),
      hasLength(1),
    );

    final isWasmScore = scores.firstWhereOrNull(
      (BenchmarkScore score) => score.metric == _isWasmScore,
    );
    expect(isWasmScore, isNotNull);
    expect(isWasmScore!.value, useWasm ? 1 : 0);
  }

  expect(
    const JsonEncoder.withIndent('  ').convert(taskResult.toJson()),
    isA<String>(),
  );
}
