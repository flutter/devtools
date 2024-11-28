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

const _extraScores = [totalUiFrameAverage, _isWasmScore];

late StringBuffer _exceededThresholds;

/// Tests that the DevTools web benchmarks are run and reported correctly.
void main() {
  setUp(() {
    _exceededThresholds = StringBuffer();
  });

  for (final useWasm in [true, false]) {
    test(
      'Can run web benchmarks with ${useWasm ? 'WASM' : 'JS'}',
      () async {
        await _runBenchmarks(useWasm: useWasm);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}

Future<void> _runBenchmarks({bool useWasm = false}) async {
  stdout.writeln('Starting web benchmark tests ...');
  final taskResult = await serveWebBenchmark(
    benchmarkAppDirectory: projectRootDirectory(),
    entryPoint: generateBenchmarkEntryPoint(useWasm: useWasm),
    compilationOptions:
        useWasm
            ? const CompilationOptions.wasm()
            : const CompilationOptions.js(),
    treeShakeIcons: false,
    benchmarkPath: benchmarkPath(useWasm: useWasm),
  );
  stdout.writeln('Web benchmark tests finished.');

  expect(
    const JsonEncoder.withIndent('  ').convert(taskResult.toJson()),
    isA<String>(),
  );
  expect(taskResult.scores.keys, hasLength(DevToolsBenchmark.values.length));

  for (final devToolsBenchmark in DevToolsBenchmark.values) {
    final benchmarkName = devToolsBenchmark.id;
    final expectedMetrics = expectedBenchmarkMetrics(useWasm: useWasm);
    const expectedComputations = BenchmarkMetricComputation.values;
    final scores = taskResult.scores[benchmarkName] ?? [];
    expect(
      scores,
      hasLength(
        expectedMetrics.length * expectedComputations.length +
            _extraScores.length,
      ),
    );

    for (final metric in expectedMetrics) {
      for (final computation in expectedComputations) {
        expect(
          scores.where(
            (score) => score.metric == _generateScoreName(metric, computation),
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

    _verifyScoresAgainstThresholds(devToolsBenchmark, scores);
  }

  expect(
    _exceededThresholds.isEmpty,
    isTrue,
    reason:
        'The following benchmark scores exceeded their expected thresholds:'
        '\n\n${_exceededThresholds.toString()}',
  );
}

void _verifyScoresAgainstThresholds(
  DevToolsBenchmark devToolsBenchmark,
  List<BenchmarkScore> scores,
) {
  stdout.writeln(
    'Verifying ${devToolsBenchmark.id} scores against expected thresholds.',
  );
  expect(
    _benchmarkThresholds.containsKey(devToolsBenchmark),
    isTrue,
    reason: 'Missing expected thresholds for ${devToolsBenchmark.id}.',
  );
  final expectedThresholds = _benchmarkThresholds[devToolsBenchmark]!;

  final scoresAsMap = Map.fromEntries([
    for (final score in scores) MapEntry(score.metric, score),
  ]);

  String exceededThresholdLine({
    required String scoreName,
    required num actualScore,
    required num threshold,
  }) {
    return '[${devToolsBenchmark.id}] $scoreName was $actualScore μs, which '
        'exceeded the expected threshold, $threshold μs.';
  }

  for (final metric in [
    BenchmarkMetric.flutterFrameTotalTime,
    BenchmarkMetric.flutterFrameBuildTime,
    BenchmarkMetric.flutterFrameRasterTime,
  ]) {
    for (final computation in [
      BenchmarkMetricComputation.average,
      BenchmarkMetricComputation.p50,
      BenchmarkMetricComputation.p90,
    ]) {
      final scoreName = _generateScoreName(metric, computation);
      final score = scoresAsMap[scoreName]!.value;
      final threshold = expectedThresholds[scoreName]!;
      if (score > threshold) {
        _exceededThresholds.writeln(
          exceededThresholdLine(
            scoreName: scoreName,
            actualScore: score,
            threshold: threshold,
          ),
        );
      }
    }
  }
}

// TODO(kenz): dial these expected values in before landing this PR.
final _benchmarkThresholds = {
  DevToolsBenchmark.navigateThroughOfflineScreens: {
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameTotalTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameBuildTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameRasterTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
  },
  DevToolsBenchmark.offlineCpuProfilerScreen: {
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameTotalTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameBuildTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameRasterTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
  },
  DevToolsBenchmark.offlinePerformanceScreen: {
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameTotalTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameBuildTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameRasterTime,
      avg: 16666.0,
      p50: 16666.0,
      p90: 16666.0,
    ),
  },
};

/// Returns a Map of benchmark score names to their expected value in micros.
Map<String, num> _valuesForMetric(
  BenchmarkMetric metric, {
  required num avg,
  required num p50,
  required num p90,
}) => {
  _generateScoreName(metric, BenchmarkMetricComputation.average): avg,
  _generateScoreName(metric, BenchmarkMetricComputation.p50): p50,
  _generateScoreName(metric, BenchmarkMetricComputation.p90): p90,
};

String _generateScoreName(
  BenchmarkMetric metric,
  BenchmarkMetricComputation computation,
) => '${metric.label}.${computation.name}';
