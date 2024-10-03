// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:web_benchmarks/analysis.dart';

File? checkFileExists(String path) {
  final testFile = File.fromUri(Uri.parse(path));
  if (!testFile.existsSync()) {
    stdout.writeln('Could not locate file at $path.');
    return null;
  }
  return testFile;
}

String convertToCsvLine(List<String> content) {
  return content.map((e) => '"$e"').join(',');
}

extension BenchmarkResultsExtension on BenchmarkResults {
  List<List<String>> toCsvLines() {
    final lines = <List<String>>[];
    for (final benchmarkName in scores.keys) {
      final scoresForBenchmark = scores[benchmarkName] ?? <BenchmarkScore>[];
      for (var i = 0; i < scoresForBenchmark.length; i++) {
        final score = scoresForBenchmark[i];
        lines.add([
          // Include the benchmark name for the line containing the first
          // score metric, and a blank cell otherwise.
          i == 0 ? benchmarkName : '',
          ...score.toCsvLine(),
        ]);
      }
    }
    return lines;
  }
}

extension BenchmarkScoreExtension on BenchmarkScore {
  List<String> toCsvLine() {
    return [
      metric, // Metric name
      value.toString(), // Value
      delta?.toString() ?? '', // Delta value
      // value - delta represents the baseline score.
      delta != null
          ? (delta! / (value - delta!)).toString()
          : '', // Delta % value
    ];
  }
}
