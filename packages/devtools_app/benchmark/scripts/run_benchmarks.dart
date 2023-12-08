// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:web_benchmarks/server.dart';

import '../test_infra/common.dart';
import '../test_infra/project_root_directory.dart';

/// Runs the DevTools web benchmarks and reports the benchmark data.
/// 
/// Arguments:
/// * --browser - runs the benchmark tests in the browser (non-headless mode)
/// * --wasm - runs the benchmark tests with the dart2wasm compiler
/// 
/// See [BenchmarkArgs].
Future<void> main(List<String> args) async {
  final benchmarkArgs = BenchmarkArgs(args);

  stdout.writeln('Starting web benchmark tests (run #$i) ...');
  final taskResult = await serveWebBenchmark(
    benchmarkAppDirectory: projectRootDirectory(),
    entryPoint: 'benchmark/test_infra/client.dart',
    compilationOptions: CompilationOptions(useWasm: benchmarkArgs.useWasm),
    treeShakeIcons: false,
    initialPage: benchmarkInitialPage,
    headless: !benchmarkArgs.useBrowser,
  );
  stdout.writeln('Web benchmark tests finished (run #$i).');

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

  static const _browserFlag = 'browser';

  static const _wasmFlag = 'wasm';

  /// Builds an arg parser for DevTools integration tests.
  static ArgParser _buildArgParser() {
    return ArgParser()
      ..addFlag(
        _browserFlag,
        help: 'Runs the benchmark tests in browser mode (not headless mode).',
      )
      ..addFlag(
        _wasmFlag,
        help: 'Runs the benchmark tests with dart2wasm',
      );
  }
}

