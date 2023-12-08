// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:web_benchmarks/server.dart';

File? checkFileExists(String path) {
  final testFile = File.fromUri(Uri.parse(path));
  if (!testFile.existsSync()) {
    stdout.writeln('Could not locate file at $path.');
    return null;
  }
  return testFile;
}

extension BenchmarkResultsExtension on BenchmarkResults {
  /// Sums this [BenchmarkResults] instance with [other] by adding the values
  /// of each matching benchmark score.
  /// 
  /// Returns a [BenchmarkResults] object with the summed values.
  BenchmarkResults sumWith(
    BenchmarkResults other, {
    bool throwExceptionOnMismatch = true,
  }) {
    final sum = toJson();
    for (final benchmark in scores.keys) {
      // Look up this benchmark in [other].
      final matchingBenchmark = other.scores[benchmark];
      if (matchingBenchmark == null) {
        if (throwExceptionOnMismatch) {
          throw Exception(
            'Cannot sum benchmarks because [other] is missing an entry for '
            'benchmark "$benchmark".',
          );
        }
        continue;
      }

      final scoresForBenchmark = scores[benchmark]!;
      for (int i = 0; i < scoresForBenchmark.length; i++) {
        final score = scoresForBenchmark[i];
        // Look up this score in the [matchingBenchmark] from [other].
        final matchingScore =
            matchingBenchmark.firstWhereOrNull((s) => s.metric == score.metric);
        if (matchingScore == null) {
          if (throwExceptionOnMismatch) {
            throw Exception(
              'Cannot sum benchmarks because benchmark "$benchmark" is missing '
              'a score for metric ${score.metric}.',
            );
          }
          continue;
        }

        final sumScore = score.value + matchingScore.value;
        sum[benchmark]![i]['value'] = sumScore;
      }
    }
    return BenchmarkResults.parse(sum);
  }
}
