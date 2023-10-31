// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../model.dart';
import '../utils.dart';

const _upgradeFlag = 'upgrade';
const _onlyMainFlag = 'only-main';

class PubGetCommand extends Command {
  PubGetCommand() {
    argParser
      ..addFlag(_upgradeFlag, negatable: false, help: 'Run pub upgrade.')
      ..addFlag(
        _onlyMainFlag,
        negatable: false,
        help: 'Only execute on the top-level `devtools/packages/devtools_*` '
            'packages and any of their subdirectories',
      );
  }

  @override
  String get name => 'pub-get';

  @override
  String get description => "Run 'flutter pub get' in all DevTools packages.";

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

    final upgrade = argResults![_upgradeFlag];
    final onlyMainPackages = argResults![_onlyMainFlag];
    final command = upgrade ? 'upgrade' : 'get';

    log.stdout('Running flutter pub $command...');

    int failureCount = 0;

    for (Package p in packages) {
      final packagePathParts = path.split(p.relativePath);
      final isMainPackageOrSubdirectory = packagePathParts.length >= 2 &&
          packagePathParts.first == 'packages' &&
          packagePathParts[1].startsWith('devtools_');
      if (onlyMainPackages && !isMainPackageOrSubdirectory) continue;

      final progress = log.progress('  ${p.relativePath}');

      final process = await processManager.runProcess(
        CliCommand.flutter(
          'pub $command',
          // Run all so we can see the full set of results instead of stopping
          // on the first error.
          throwOnException: false,
        ),
        workingDirectory: p.packagePath,
      );

      final exitCode = process.exitCode;
      if (exitCode == 0) {
        progress.finish(showTiming: true);
      } else {
        failureCount++;
        progress.finish(message: 'failed (exit code $exitCode)');
      }
    }

    return failureCount == 0 ? 0 : 1;
  }
}
