// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
///
/// To run locally:
///
/// flutter test benchmark/devtools_benchmarks_test.dart
void main() {
  setUp(() {
    _exceededThresholds = StringBuffer();
  });

  tearDown(() {
    _exceededThresholds.clear();
  });

  for (final useWasm in [true, false]) {
    test(
      'Can run web benchmarks with ${useWasm ? 'WASM' : 'JS'}',
      () async {
        await _runBenchmarks(useWasm: useWasm);
      },
      timeout: const Timeout(Duration(minutes: 10)),
      retry: 1,
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

    _verifyScoresAgainstThresholds(devToolsBenchmark, scores, useWasm: useWasm);
  }

  final exceededThresholdsAsString = _exceededThresholds.toString();
  expect(
    exceededThresholdsAsString,
    isEmpty,
    reason:
        '[${useWasm ? 'WASM' : 'JS'} Benchmarks] The following benchmark '
        'scores exceeded their expected thresholds:'
        '\n\n$exceededThresholdsAsString',
  );
}

void _verifyScoresAgainstThresholds(
  DevToolsBenchmark devToolsBenchmark,
  List<BenchmarkScore> scores, {
  required bool useWasm,
}) {
  final identifier = '${devToolsBenchmark.id}.${useWasm ? 'wasm' : 'js'}';
  stdout.writeln('Verifying $identifier scores against expected thresholds.');
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
    return '[$identifier] $scoreName was $actualScore μs, which '
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

const _frameTimeFor60FPSInMicros = 16666.6;

final _benchmarkThresholds = {
  // Note that some of these benchmarks exceed the 60fps frame budget,
  // especially the p90 benchmarks.
  //
  // See https://github.com/flutter/devtools/pull/8892 which exposes this.
  DevToolsBenchmark.navigateThroughOfflineScreens: {
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameTotalTime,
      avg: _frameTimeFor60FPSInMicros * 2,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros * 6,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameBuildTime,
      avg: _frameTimeFor60FPSInMicros * 2,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameRasterTime,
      avg: _frameTimeFor60FPSInMicros * 2,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros,
    ),
  },
  // Note that some of these benchmarks exceed the 60fps frame budget,
  // especially the p90 benchmarks.
  //
  // See https://github.com/flutter/devtools/pull/8892 which exposes this.
  DevToolsBenchmark.offlineCpuProfilerScreen: {
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameTotalTime,
      avg: _frameTimeFor60FPSInMicros * 2,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros * 6,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameBuildTime,
      avg: _frameTimeFor60FPSInMicros * 2,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameRasterTime,
      avg: _frameTimeFor60FPSInMicros * 2,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros,
    ),
  },
  DevToolsBenchmark.offlinePerformanceScreen: {
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameTotalTime,
      avg: _frameTimeFor60FPSInMicros,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameBuildTime,
      avg: _frameTimeFor60FPSInMicros,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros,
    ),
    ..._valuesForMetric(
      BenchmarkMetric.flutterFrameRasterTime,
      avg: _frameTimeFor60FPSInMicros,
      p50: _frameTimeFor60FPSInMicros,
      p90: _frameTimeFor60FPSInMicros,
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
