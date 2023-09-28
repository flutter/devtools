// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';

import '../model.dart';
import '../utils.dart';

class AnalyzeCommand extends Command {
  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyze all DevTools packages.';

  @override
  Future run() async {
    final sdk = FlutterSdk.getSdk();
    if (sdk == null) {
      print('Unable to locate a Flutter sdk.');
      return 1;
    }

    final log = Logger.standard();
    final repo = DevToolsRepo.requireInstance();
    final packages = repo.getPackages();

    log.stdout('Running flutter analyze...');

    int failureCount = 0;

    for (Package p in packages) {
      if (!p.hasAnyDartCode) {
        continue;
      }

      final progress = log.progress('  ${p.relativePath}');

      final process = await Process.start(
        sdk.dartToolPath,
        ['analyze', '--fatal-infos'],
        workingDirectory: p.packagePath,
      );
      final Stream<List<int>> stdout = process.stdout;
      final Stream<List<int>> stderr = process.stderr;

      final int exitCode = await process.exitCode;

      if (exitCode == 0) {
        progress.finish(showTiming: true);
      } else {
        failureCount++;

        // Display stderr when there's an error.
        final List<List<int>> out = await stdout.toList();
        final stdOutput = convertProcessOutputToString(out, '    ');

        final List<List<int>> err = await stderr.toList();
        final errorOutput = convertProcessOutputToString(err, '    ');

        progress.finish(message: 'failed');

        log.stderr(stdOutput);
        log.stderr(log.ansi.error(errorOutput));
      }
    }

    return failureCount == 0 ? 0 : 1;
  }
}
