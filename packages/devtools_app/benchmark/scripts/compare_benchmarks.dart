// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:web_benchmarks/server.dart';

import 'utils.dart';

/// Compares two sets of web benchmarks and calculates the delta between each
/// matching metric.
void main(List<String> args) {
  if (args.length != 2) {
    throw Exception(
      'Expected 2 arguments (<baseline-file>, <test-file>), but instead there '
      'were ${args.length}.',
    );
  }

  final baselineSource = args[0];
  final testSource = args[1];

  stdout
    ..writeln('Comparing the following benchmark results:')
    ..writeln('    "$testSource" (test)')
    ..writeln('    "$baselineSource" (baseline)');

  final baselineFile = checkFileExists(baselineSource);
  final testFile = checkFileExists(testSource);
  if (baselineFile == null || testFile == null) {
    if (baselineFile == null) {
      throw Exception('Cannot find baseline file $baselineSource');
    }
    if (testFile == null) {
      throw Exception('Cannot find test file $testSource');
    }
  }

  final baselineResults =
      BenchmarkResults.parse(jsonDecode(baselineFile.readAsStringSync()));
  final testResults =
      BenchmarkResults.parse(jsonDecode(testFile.readAsStringSync()));
  compareBenchmarks(
    baselineResults,
    testResults,
    baselineSource: baselineSource,
  );
}

void compareBenchmarks(
  BenchmarkResults baseline,
  BenchmarkResults test, {
  required String baselineSource,
}) {
  stdout.writeln('Starting baseline comparison...');

  for (final benchmarkName in test.scores.keys) {
    stdout.writeln('Comparing metrics for benchmark "$benchmarkName".');

    // Lookup this benchmark in the baseline.
    final baselineScores = baseline.scores[benchmarkName];
    if (baselineScores == null) {
      stdout.writeln(
        'Baseline does not contain results for benchmark "$benchmarkName".',
      );
      continue;
    }

    final testScores = test.scores[benchmarkName]!;

    for (final score in testScores) {
      // Lookup this metric in the baseline.
      final baselineScore =
          baselineScores.firstWhereOrNull((s) => s.metric == score.metric);
      if (baselineScore == null) {
        stdout.writeln(
          'Baseline does not contain metric "${score.metric}" for '
          'benchmark "$benchmarkName".',
        );
        continue;
      }

      // Add the delta to the [testMetric].
      _benchmarkDeltas[score] = (score.value - baselineScore.value).toDouble();
    }
  }
  stdout.writeln('Baseline comparison finished.');

  stdout
    ..writeln('==== Comparison with baseline $baselineSource ====')
    ..writeln(
      const JsonEncoder.withIndent('  ').convert(test.toJsonWithDeltas()),
    )
    ..writeln('==== End of baseline comparison ====');
}

Expando<double> _benchmarkDeltas = Expando<double>();

extension ScoreDeltaExtension on BenchmarkScore {
  double? get deltaFromBaseline => _benchmarkDeltas[this];
}

extension ResultDeltaExtension on BenchmarkResults {
  Map<String, List<Map<String, dynamic>>> toJsonWithDeltas() {
    return scores.map<String, List<Map<String, dynamic>>>(
      (String benchmarkName, List<BenchmarkScore> scores) {
        return MapEntry<String, List<Map<String, dynamic>>>(
          benchmarkName,
          scores.map<Map<String, dynamic>>(
            (BenchmarkScore score) {
              final delta = _benchmarkDeltas[score];
              return <String, dynamic>{
                ...score.toJson(),
                if (delta != null) 'delta': delta,
              };
            },
          ).toList(),
        );
      },
    );
  }
}
