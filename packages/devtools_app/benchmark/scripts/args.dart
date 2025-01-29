// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:args/args.dart';

/// A base class for handling arguments for benchmarks scripts.
abstract class BenchmarkArgsBase {
  late final ArgParser argParser;
  late final ArgResults argResults;

  static const _saveToFileOption = 'save-to-file';
  static const _baselineOption = 'baseline';
  static const _averageOfOption = 'average-of';

  int get averageOf => int.parse(argResults[_averageOfOption]);
  String? get saveToFileLocation => argResults[_saveToFileOption];
  String? get baselineLocation => argResults[_baselineOption];

  /// Initializes [argParser] and parses [args] into [argResults].
  void init(List<String> args, {required ArgParser parser}) {
    argParser = parser;
    argResults = argParser.parse(args);
  }
}

/// Extension methods to add [ArgParser] options for benchmarks scripts.
extension BenchmarkArgsExtension on ArgParser {
  void addSaveToFileOption(BenchmarkResultsOutputType type) {
    addOption(
      BenchmarkArgument.saveToFile.flagName,
      help:
          'Saves the benchmark results to a ${type.name} file at the '
          'provided path (absolute).',
      valueHelp: '/Users/me/Downloads/output.${type.name}',
    );
  }

  void addAverageOfOption() {
    addOption(
      BenchmarkArgument.averageOf.flagName,
      defaultsTo: '1',
      help:
          'The number of times to run the benchmark. The returned results '
          'will be the average of all the benchmark runs when this value is '
          'greater than 1.',
      valueHelp: '5',
    );
  }

  void addBaselineOption({String? additionalHelp}) {
    addOption(
      BenchmarkArgument.baseline.flagName,
      help:
          'The baseline benchmark data to compare the test benchmark run to. '
          '${additionalHelp ?? ''}',
      valueHelp: '/Users/me/Downloads/baseline.json',
    );
  }
}

/// The possible argument names for benchmark script [ArgParser]s.
enum BenchmarkArgument {
  averageOf(flagName: 'average-of'),
  baseline,
  browser,
  saveToFile(flagName: 'save-to-file'),
  test,
  wasm;

  const BenchmarkArgument({String? flagName}) : _flagName = flagName;

  String get flagName => _flagName ?? name;

  final String? _flagName;
}

/// The file types that benchmark results may be written to.
enum BenchmarkResultsOutputType { csv, json }
