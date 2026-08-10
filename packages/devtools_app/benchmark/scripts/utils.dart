// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:web_benchmarks/analysis.dart';

/// Returns a pretty-printed representation of a JSON payload.
String prettyPrintJson(Object? json) =>
    const JsonEncoder.withIndent('  ').convert(json);

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
    final deltaValue = delta;
    final baselineValue = deltaValue != null ? value - deltaValue : null;
    final deltaPercent =
        (deltaValue != null && baselineValue != null && baselineValue != 0)
        ? (deltaValue / baselineValue).toString()
        : (deltaValue != null && baselineValue == 0 ? 'N/A' : '');
    return [
      metric, // Metric name
      baselineValue?.toString() ?? '', // Baseline value
      value.toString(), // Test value
      deltaValue?.toString() ?? '', // Delta value
      deltaPercent, // Delta % value
    ];
  }
}
