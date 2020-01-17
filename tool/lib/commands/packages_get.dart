// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';

import '../model.dart';
import '../utils.dart';

class PackagesGetCommand extends Command {
  @override
  String get name => 'packages-get';

  @override
  String get description => "Run 'pub get' in all DevTools packages.";

  @override
  Future run() async {
    final FlutterSdk sdk = FlutterSdk.getSdk();
    if (sdk == null) {
      print('Unable to locate a Flutter sdk.');
      return 1;
    }

    final Logger log = Logger.standard();

    final DevToolsRepo repo = DevToolsRepo.getInstance();

    final List<Package> packages = repo.getPackages();

    log.stdout('Running flutter packages get...');

    int failureCount = 0;

    for (Package p in packages) {
      final Progress progress = log.progress('  ${p.relativePath}');

      final Process process = await Process.start(
          sdk.flutterToolPath, ['packages', 'get'],
          workingDirectory: p.packagePath);
      final Stream<List<int>> stderr = process.stderr;

      final int exitCode = await process.exitCode;

      if (exitCode == 0) {
        progress.finish(showTiming: true);
      } else {
        failureCount++;

        // Display stderr when pub get goes wrong.
        final List<List<int>> err = await stderr.toList();
        final String errorOutput = convertProcessOutputToString(err, '    ');
        progress.finish(message: 'failed (exit code $exitCode)');

        log.stderr(log.ansi.error(errorOutput));
      }
    }

    return failureCount == 0 ? 0 : 1;
  }
}
