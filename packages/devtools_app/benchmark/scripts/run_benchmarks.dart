// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:web_benchmarks/analysis.dart';
import 'package:web_benchmarks/server.dart';

import '../test_infra/common.dart';
import '../test_infra/project_root_directory.dart';
import 'args.dart';
import 'compare_benchmarks.dart';
import 'utils.dart';

/// Runs the DevTools web benchmarks and reports the benchmark data.
///
/// To see available arguments, run this script with the `-h` flag.
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '-h') {
    stdout.writeln(_Args._buildArgParser().usage);
    return;
  }

  final benchmarkArgs = _Args(args);
  final results = await runBenchmarks(
    averageOf: benchmarkArgs.averageOf,
    useWasm: benchmarkArgs.useWasm,
    useBrowser: benchmarkArgs.useBrowser,
  );

  printAndMaybeSaveResults(
    benchmarkResults: results,
    saveToFileLocation: benchmarkArgs.saveToFileLocation,
  );

  maybeCompareToBaseline(
    benchmarkResults: results,
    baselineLocation: benchmarkArgs.baselineLocation,
  );
}

/// Runs the DevTools benchmarks [averageOf] times and takes returns the average
/// of the benchmark runs as a single [BenchmarkResults] object.
Future<BenchmarkResults> runBenchmarks({
  required int averageOf,
  required bool useWasm,
  required bool useBrowser,
}) async {
  final benchmarkResults = <BenchmarkResults>[];
  for (var i = 1; i <= averageOf; i++) {
    stdout.writeln('Starting web benchmark tests (run #$i) ...');
    benchmarkResults.add(
      await serveWebBenchmark(
        benchmarkAppDirectory: projectRootDirectory(),
        entryPoint: generateBenchmarkEntryPoint(useWasm: useWasm),
        compilationOptions:
            useWasm
                ? const CompilationOptions.wasm()
                : const CompilationOptions.js(),
        treeShakeIcons: false,
        benchmarkPath: benchmarkPath(useWasm: useWasm),
        headless: !useBrowser,
      ),
    );
    stdout.writeln('Web benchmark tests finished (run #$i).');
  }

  late final BenchmarkResults taskResult;
  if (averageOf == 1) {
    taskResult = benchmarkResults.first;
  } else {
    stdout.writeln(
      'Taking the average of ${benchmarkResults.length} benchmark runs.',
    );
    taskResult = computeAverage(benchmarkResults);
  }
  return taskResult;
}

/// Prints the [benchmarkResults] to stdout and optionally saves the results to
/// disk at [saveToFileLocation] when this value is non-null.
void printAndMaybeSaveResults({
  required BenchmarkResults benchmarkResults,
  required String? saveToFileLocation,
}) {
  final resultsAsMap = benchmarkResults.toJson();
  final resultsAsJsonString = const JsonEncoder.withIndent(
    '  ',
  ).convert(resultsAsMap);

  if (saveToFileLocation != null) {
    final location = Uri.parse(saveToFileLocation);
    File.fromUri(location)
      ..createSync()
      ..writeAsStringSync(resultsAsJsonString);
  }

  stdout
    ..writeln('==== Results ====')
    ..writeln(resultsAsJsonString)
    ..writeln('==== End of results ====')
    ..writeln();
}

/// Compares [benchmarkResults] to the benchmark results contained at the
/// [baselineLocation] absolute file path, if they exist.
///
/// This method computes a diff of the two benchmark runs and prints the delta
/// information to stdout.
void maybeCompareToBaseline({
  required BenchmarkResults benchmarkResults,
  required String? baselineLocation,
}) {
  if (baselineLocation != null) {
    final baselineFile = checkFileExists(baselineLocation);
    if (baselineFile != null) {
      final baselineResults = BenchmarkResults.parse(
        jsonDecode(baselineFile.readAsStringSync()),
      );
      compareBenchmarks(
        baselineResults,
        benchmarkResults,
        baselineSource: baselineLocation,
      );
    }
  }
}

class _Args extends BenchmarkArgsBase {
  _Args(List<String> args) {
    init(args, parser: _buildArgParser());
  }

  bool get useBrowser => argResults[BenchmarkArgument.browser.flagName];
  bool get useWasm => argResults[BenchmarkArgument.wasm.flagName];

  static ArgParser _buildArgParser() {
    return ArgParser()
      ..addSaveToFileOption(BenchmarkResultsOutputType.json)
      ..addAverageOfOption()
      ..addBaselineOption()
      ..addFlag(
        BenchmarkArgument.browser.flagName,
        negatable: false,
        help: 'Runs the benchmark tests in browser mode (not headless mode).',
      )
      ..addFlag(
        BenchmarkArgument.wasm.flagName,
        negatable: false,
        help: 'Runs the benchmark tests with dart2wasm',
      );
  }
}
