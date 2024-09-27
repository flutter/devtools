// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:io/io.dart';

import '../model.dart';
import '../utils.dart';

const _fatalInfosArg = 'fatal-infos';

class AnalyzeCommand extends Command {
  AnalyzeCommand() {
    argParser.addFlag(
      'fatal-infos',
      help: 'Sets the "fatal-infos" flag for the dart analyze command',
      defaultsTo: true,
      negatable: true,
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
    final packages = repo.getPackages();
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
