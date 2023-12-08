// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:web_benchmarks/server.dart';

import '../test_infra/common.dart';
import '../test_infra/project_root_directory.dart';
import 'compare_benchmarks.dart';
import 'utils.dart';

/// Runs the DevTools web benchmarks and reports the benchmark data.
///
/// Arguments:
/// * --browser - runs the benchmark tests in the browser (non-headless mode)
/// * --wasm - runs the benchmark tests with the dart2wasm compiler
///
/// See [BenchmarkArgs].
Future<void> main(List<String> args) async {
  final benchmarkArgs = BenchmarkArgs(args);

  stdout.writeln('Starting web benchmark tests...');
  final taskResult = await serveWebBenchmark(
    benchmarkAppDirectory: projectRootDirectory(),
    entryPoint: 'benchmark/test_infra/client.dart',
    compilationOptions: CompilationOptions(useWasm: benchmarkArgs.useWasm),
    treeShakeIcons: false,
    initialPage: benchmarkInitialPage,
    headless: !benchmarkArgs.useBrowser,
  );
  stdout.writeln('Web benchmark tests finished.');

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

  String? get saveToFileLocation => argResults[_saveToFileOption];

  String? get baselineLocation => argResults[_baselineOption];

  static const _browserFlag = 'browser';

  static const _wasmFlag = 'wasm';

  static const _baselineOption = 'baseline';

  static const _saveToFileOption = 'save-to-file';

  /// Builds an arg parser for DevTools benchmarks.
  static ArgParser _buildArgParser() {
    return ArgParser()
      ..addFlag(
        _browserFlag,
        help: 'Runs the benchmark tests in browser mode (not headless mode).',
      )
      ..addFlag(
        _wasmFlag,
        help: 'Runs the benchmark tests with dart2wasm',
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
      );
  }
}
