// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:io/io.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import '../model.dart';
import '../utils.dart';

class PresubmitCommand extends Command {
  PresubmitCommand({@visibleForTesting this.processManager}) {
    argParser.addFlag(
      'fix',
      help: 'Apply dart fixes and formatting.',
      defaultsTo: false,
      negatable: false,
    );
  }

  ProcessManager? processManager;

  @override
  String get name => 'presubmit';

  @override
  String get description =>
      'Run repo checks, analysis, fix, and format on all packages.';

  @override
  Future run() async {
    final log = Logger.standard();
    final repo = DevToolsRepo.getInstance();
    final pm = processManager ?? ProcessManager();
    final fix = argResults!['fix'] as bool;

    log.stdout('Running pub get...');
    final pubGetResult = await runner?.run(['pub-get']);
    if (pubGetResult is int && pubGetResult != 0) {
      log.stderr('Pub get failed. Exiting early.');
      return 1;
    }

    final packages = repo.getPackages(includeSubdirectories: false);
    int failureCount = 0;

    if (fix) {
      log.stdout('Running Dart Fix and Format...');
      for (final p in packages) {
        if (!p.hasAnyDartCode) continue;

        final progress = log.progress('  ${p.relativePath}');

        final fixProcess = await pm.runProcess(
          CliCommand.dart(['fix', '--apply'], throwOnException: false),
          workingDirectory: p.packagePath,
        );

        final pathsToFormat = _getPathsToFormat(p);

        final formatProcess = await pm.runProcess(
          CliCommand.dart([
            'format',
            ...pathsToFormat,
          ], throwOnException: false),
          workingDirectory: p.packagePath,
        );

        if (fixProcess.exitCode == 0 && formatProcess.exitCode == 0) {
          progress.finish(showTiming: true);
        } else {
          failureCount++;
          progress.finish(message: 'failed');
        }
      }

      if (failureCount > 0) {
        log.stderr('Presubmit failed.');
        log.stderr('  Fix or Format failed on $failureCount packages.');
        return 1;
      }
    }

    log.stdout('Running Repo Check...');
    final repoCheckResult = await runner?.run(['repo-check']);
    if (repoCheckResult is int && repoCheckResult != 0) {
      log.stderr('Repo checks failed. Exiting early.');
      return 1;
    }

    log.stdout('Running Analyze...');
    final analyzeResult = await runner?.run(['analyze']);
    if (analyzeResult is int && analyzeResult != 0) {
      log.stderr('Analysis failed. Exiting early.');
      return 1;
    }

    if (!fix) {
      log.stdout('Running Dart Format Check...');
      for (final p in packages) {
        if (!p.hasAnyDartCode) continue;

        final progress = log.progress('  ${p.relativePath}');

        final pathsToFormat = _getPathsToFormat(p);

        final formatProcess = await pm.runProcess(
          CliCommand.dart([
            'format',
            '--output=none',
            '--set-exit-if-changed',
            ...pathsToFormat,
          ], throwOnException: false),
          workingDirectory: p.packagePath,
        );

        if (formatProcess.exitCode == 0) {
          progress.finish(showTiming: true);
        } else {
          failureCount++;
          progress.finish(message: 'failed');
        }
      }

      if (failureCount > 0) {
        log.stderr('Presubmit failed.');
        log.stderr('  Formatting issues found in $failureCount packages.');
        return 1;
      }
    }

    log.stdout('Presubmit passed!');
    return 0;
  }

  List<String> _getPathsToFormat(Package p) {
    final pathsToFormat = <String>[];
    if (p.relativePath == 'tool') {
      final children = Directory(p.packagePath).listSync();
      for (final entity in children) {
        final name = path.basename(entity.path);
        if (name.startsWith('.')) continue;
        if (name == 'flutter-sdk') continue;
        if (entity is Directory) {
          pathsToFormat.add(name);
        } else if (entity is File && name.endsWith('.dart')) {
          pathsToFormat.add(name);
        }
      }
    } else {
      pathsToFormat.add('.');
    }
    return pathsToFormat;
  }
}
