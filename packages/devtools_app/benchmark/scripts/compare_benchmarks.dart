// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:web_benchmarks/analysis.dart';

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
  final delta = computeDelta(baseline, test);
  stdout.writeln('Baseline comparison finished.');
  stdout
    ..writeln('==== Comparison with baseline $baselineSource ====')
    ..writeln(const JsonEncoder.withIndent('  ').convert(delta))
    ..writeln('==== End of baseline comparison ====');
}
