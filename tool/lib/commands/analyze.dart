// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:io/io.dart';

import '../model.dart';
import '../utils.dart';

const _fatalInfosArg = 'fatal-infos';
const _skipUnimportantArg = 'skip-unimportant';

const _unimportantDirectories = ['case_study', 'fixtures'];

class AnalyzeCommand extends Command {
  AnalyzeCommand() {
    argParser
      ..addFlag(
        _fatalInfosArg,
        help: 'Sets the "fatal-infos" flag for the dart analyze command',
        defaultsTo: true,
        negatable: true,
      )
      ..addFlag(
        _skipUnimportantArg,
        help:
            'Skips analysis for unimportant directories '
            '${_unimportantDirectories.toString()}',
        defaultsTo: false,
        negatable: false,
      );
  }

  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyze all DevTools packages.';

  @override
  Future run() async {
    final log = Logger.standard();
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();
    final skipUnimportant = argResults![_skipUnimportantArg] as bool;
    final packages = repo.getPackages(
      skip: skipUnimportant ? _unimportantDirectories : [],
      // Analyzing packages that are subdirectories of another package is
      // redundant.
      includeSubdirectories: false,
    );
    final fatalInfos = argResults![_fatalInfosArg] as bool;

    log.stdout('Running flutter analyze...');

    int failureCount = 0;

    for (final p in packages) {
      if (!p.hasAnyDartCode) {
        continue;
      }

      final progress = log.progress('  ${p.relativePath}');

      final process = await processManager.runProcess(
        CliCommand.dart(
          ['analyze', if (fatalInfos) '--fatal-infos'],
          // Run all so we can see the full set of results instead of stopping
          // on the first error.
          throwOnException: false,
        ),
        workingDirectory: p.packagePath,
      );

      if (process.exitCode == 0) {
        progress.finish(showTiming: true);
      } else {
        failureCount++;

        progress.finish(message: 'failed');
      }
    }

    return failureCount == 0 ? 0 : 1;
  }
}
