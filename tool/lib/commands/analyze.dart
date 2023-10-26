// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:io/io.dart';

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
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();
    final packages = repo.getPackages();

    log.stdout('Running flutter analyze...');

    int failureCount = 0;

    for (Package p in packages) {
      if (!p.hasAnyDartCode) {
        continue;
      }

      final progress = log.progress('  ${p.relativePath}');

      final process = await processManager.runProcess(
        CliCommand.from(
          sdk.dartToolPath,
          ['analyze', '--fatal-infos'],
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
