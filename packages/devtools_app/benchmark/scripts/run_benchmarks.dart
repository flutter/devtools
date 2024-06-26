// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:web_benchmarks/analysis.dart';
import 'package:web_benchmarks/server.dart';

import '../test_infra/common.dart';
import '../test_infra/project_root_directory.dart';
import 'compare_benchmarks.dart';
import 'utils.dart';

/// Runs the DevTools web benchmarks and reports the benchmark data.
///
/// To see available arguments, run this script with the `-h` flag.
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '-h') {
    stdout.writeln(BenchmarkArgs._buildArgParser().usage);
    return;
  }

  final benchmarkArgs = BenchmarkArgs(args);
  final benchmarkResults = <BenchmarkResults>[];
  for (var i = 0; i < benchmarkArgs.averageOf; i++) {
    stdout.writeln('Starting web benchmark tests (run #$i) ...');
    benchmarkResults.add(
      await serveWebBenchmark(
        benchmarkAppDirectory: projectRootDirectory(),
        entryPoint: 'benchmark/test_infra/client.dart',
        compilationOptions: CompilationOptions(
          useWasm: benchmarkArgs.useWasm,
          renderer: benchmarkArgs.useSkwasm
              ? WebRenderer.skwasm
              : WebRenderer.canvaskit,
        ),
        treeShakeIcons: false,
        initialPage: benchmarkInitialPage,
        headless: !benchmarkArgs.useBrowser,
      ),
    );
    stdout.writeln('Web benchmark tests finished (run #$i).');
  }

  late final BenchmarkResults taskResult;
  if (benchmarkArgs.averageOf == 1) {
    taskResult = benchmarkResults.first;
  } else {
    stdout.writeln(
      'Taking the average of ${benchmarkResults.length} benchmark runs.',
    );
    taskResult = computeAverage(benchmarkResults);
  }

  final resultsAsMap = taskResult.toJson();
  final resultsAsJsonString =
      const JsonEncoder.withIndent('  ').convert(resultsAsMap);

  if (benchmarkArgs.saveToFileLocation != null) {
    final location = Uri.parse(benchmarkArgs.saveToFileLocation!);
    File.fromUri(location)
      ..createSync()
      ..writeAsStringSync(resultsAsJsonString);
  }

  stdout
    ..writeln('==== Results ====')
    ..writeln(resultsAsJsonString)
    ..writeln('==== End of results ====')
    ..writeln();

  final baselineSource = benchmarkArgs.baselineLocation;
  if (baselineSource != null) {
    final baselineFile = checkFileExists(baselineSource);
    if (baselineFile != null) {
      final baselineResults = BenchmarkResults.parse(
        jsonDecode(baselineFile.readAsStringSync()),
      );
      final testResults = BenchmarkResults.parse(
        jsonDecode(resultsAsJsonString),
      );
      compareBenchmarks(
        baselineResults,
        testResults,
        baselineSource: baselineSource,
      );
    }
  }
}

class BenchmarkArgs {
  BenchmarkArgs(List<String> args) {
    argParser = _buildArgParser();
    argResults = argParser.parse(args);
  }

  late final ArgParser argParser;

  late final ArgResults argResults;

  bool get useBrowser => argResults[_browserFlag];

  bool get useWasm => argResults[_wasmFlag];

  bool get useSkwasm => argResults[_skwasmFlag];

  int get averageOf => int.parse(argResults[_averageOfOption]);

  String? get saveToFileLocation => argResults[_saveToFileOption];

  String? get baselineLocation => argResults[_baselineOption];

  static const _browserFlag = 'browser';

  static const _wasmFlag = 'wasm';

  static const _skwasmFlag = 'skwasm';

  static const _saveToFileOption = 'save-to-file';

  static const _baselineOption = 'baseline';

  static const _averageOfOption = 'average-of';

  /// Builds an arg parser for DevTools benchmarks.
  static ArgParser _buildArgParser() {
    return ArgParser()
      ..addFlag(
        _browserFlag,
        negatable: false,
        help: 'Runs the benchmark tests in browser mode (not headless mode).',
      )
      ..addFlag(
        _wasmFlag,
        negatable: false,
        help: 'Runs the benchmark tests with dart2wasm',
      )
      ..addFlag(
        _skwasmFlag,
        negatable: false,
        help:
            'Runs the benchmark tests with the skwasm renderer instead of canvaskit.',
      )
      ..addOption(
        _saveToFileOption,
        help: 'Saves the benchmark results to a JSON file at the given path.',
        valueHelp: '/Users/me/Downloads/output.json',
      )
      ..addOption(
        _baselineOption,
        help: 'The baseline benchmark data to compare this test run to. The '
            'baseline file should be created by running this script with the '
            '$_saveToFileOption in a separate test run.',
        valueHelp: '/Users/me/Downloads/baseline.json',
      )
      ..addOption(
        _averageOfOption,
        defaultsTo: '1',
        help: 'The number of times to run the benchmark. The returned results '
            'will be the average of all the benchmark runs when this value is '
            'greater than 1.',
        valueHelp: '5',
      );
  }
}
