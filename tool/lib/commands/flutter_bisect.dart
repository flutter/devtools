// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';
import 'flutter_bisect_helper.dart';

const _fromArg = 'from';
const _toArg = 'to';
const _testArg = 'test';
const _packageArg = 'package';
const _dryRunArg = 'dry-run';
const _keepSdkArg = 'keep-sdk';
const _skipVerifyArg = 'skip-verify';

final _flutterPreReleaseTagRegExp = RegExp(r'[0-9]+.[0-9]+.0-[0-9]+.0.pre');

/// Bisects Flutter SDK commits in `tool/flutter-sdk` to find which commit
/// introduced a DevTools test regression.
///
/// Example:
/// `dt flutter-bisect --from <good> --to <bad> --test path/to/test.dart`
class FlutterBisectCommand extends Command {
  FlutterBisectCommand() {
    argParser
      ..addOption(
        _fromArg,
        help: 'Known-good Flutter commit or ref (test passes).',
        valueHelp: 'sha',
        mandatory: true,
      )
      ..addOption(
        _toArg,
        help: 'Known-bad Flutter commit or ref (test fails).',
        valueHelp: 'sha',
        mandatory: true,
      )
      ..addOption(
        _testArg,
        help: 'Path to the failing DevTools test file.',
        valueHelp: 'path/to/test.dart',
        mandatory: true,
      )
      ..addOption(
        _packageArg,
        help:
            'Package directory used as the working directory for '
            '`flutter test`. Defaults to the nearest directory containing '
            'pubspec.yaml above the test file.',
        valueHelp: 'path',
      )
      ..addFlag(
        _dryRunArg,
        negatable: false,
        help:
            'Print the commit range that would be searched without checking '
            'out Flutter or running tests.',
      )
      ..addFlag(
        _keepSdkArg,
        negatable: false,
        help:
            'Leave tool/flutter-sdk on the last checked commit instead of '
            'restoring flutter-candidate.txt.',
      )
      ..addFlag(
        _skipVerifyArg,
        negatable: false,
        help:
            'Skip verifying that --from passes and --to fails before bisecting.',
      );
  }

  @override
  String get name => 'flutter-bisect';

  @override
  String get description =>
      'Binary-search Flutter SDK commits in tool/flutter-sdk to find which '
      'commit introduced a failing DevTools test.';

  @override
  Future<int> run() async {
    final log = Logger.standard();
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();

    int fail(String message) {
      log.stderr(message);
      return 1;
    }

    final fromRef = argResults![_fromArg] as String;
    final toRef = argResults![_toArg] as String;
    final testArg = argResults![_testArg] as String;
    final dryRun = argResults![_dryRunArg] as bool;
    final keepSdk = argResults![_keepSdkArg] as bool;
    final skipVerify = argResults![_skipVerifyArg] as bool;

    final testPath = path.isAbsolute(testArg)
        ? testArg
        : path.normalize(path.join(repo.repoPath, testArg));
    if (!File(testPath).existsSync()) {
      return fail('Test file not found: $testPath');
    }

    final packageArg = argResults![_packageArg] as String?;
    final packageDir = packageArg == null
        ? findPackageDirectory(testPath)
        : (path.isAbsolute(packageArg)
              ? packageArg
              : path.normalize(path.join(repo.repoPath, packageArg)));
    if (packageDir == null || !Directory(packageDir).existsSync()) {
      return fail(
        'Could not find a package directory (pubspec.yaml) for test: $testPath. '
        'Pass --package explicitly.',
      );
    }

    final sdkPath = repo.toolFlutterSdkPath;
    await _ensureFlutterSdk(repo, processManager, log);

    final fromSha = await _revParse(processManager, sdkPath, fromRef);
    final toSha = await _revParse(processManager, sdkPath, toRef);

    final isAncestor = await _isAncestor(
      processManager,
      sdkPath,
      ancestor: fromSha,
      descendant: toSha,
    );
    if (!isAncestor) {
      return fail(
        '--from ($fromSha) is not an ancestor of --to ($toSha). '
        'Fetch the Flutter history and ensure your good commit comes before '
        'your bad commit.',
      );
    }

    final commits = await _commitsBetween(
      processManager,
      sdkPath,
      fromSha: fromSha,
      toSha: toSha,
    );
    if (commits.isEmpty) {
      return fail(
        'No commits found between --from ($fromSha) and --to ($toSha).',
      );
    }

    log.stdout(
      'Found ${commits.length} commit(s) after --from up to and including --to.',
    );
    if (dryRun) {
      for (final commit in commits) {
        log.stdout(commit);
      }
      return 0;
    }

    final restoreRef = _candidateRestoreRef(repo);
    var step = 0;
    final totalEstimate = skipVerify
        ? _approxBisectSteps(commits.length)
        : 2 + _approxBisectSteps(commits.length);

    Future<bool> isBad(String sha) async {
      step += 1;
      log.stdout('');
      log.stdout('[$step/~$totalEstimate] Checking $sha ...');
      await _checkoutFlutter(processManager, sdkPath, sha);
      final passed = await _runTest(
        processManager,
        sdkPath: sdkPath,
        packageDir: packageDir,
        testPath: testPath,
        log: log,
      );
      log.stdout(passed ? 'Result: PASS (good)' : 'Result: FAIL (bad)');
      return !passed;
    }

    try {
      if (!skipVerify) {
        log.stdout('Verifying endpoints before bisect...');
        log.stdout('Verifying --from ($fromSha) passes...');
        await _checkoutFlutter(processManager, sdkPath, fromSha);
        final fromPassed = await _runTest(
          processManager,
          sdkPath: sdkPath,
          packageDir: packageDir,
          testPath: testPath,
          log: log,
        );
        step += 1;
        if (!fromPassed) {
          return fail(
            '--from commit does not pass the test; check your good/bad range.',
          );
        }
        log.stdout('--from passed.');

        log.stdout('Verifying --to ($toSha) fails...');
        await _checkoutFlutter(processManager, sdkPath, toSha);
        final toPassed = await _runTest(
          processManager,
          sdkPath: sdkPath,
          packageDir: packageDir,
          testPath: testPath,
          log: log,
        );
        step += 1;
        if (toPassed) {
          return fail('--to commit passes the test; nothing to bisect.');
        }
        log.stdout('--to failed as expected.');
      }

      final firstBad = await findFirstBadCommitAsync(commits, isBad: isBad);
      final subject = await _commitSubject(processManager, sdkPath, firstBad);

      log.stdout('');
      log.stdout('First bad commit: $firstBad $subject');
      log.stdout('https://github.com/flutter/flutter/commit/$firstBad');
      return 0;
    } finally {
      if (!keepSdk) {
        log.stdout('');
        log.stdout('Restoring tool/flutter-sdk to $restoreRef ...');
        try {
          await _checkoutFlutter(processManager, sdkPath, restoreRef);
          log.stdout('Restored tool/flutter-sdk.');
        } catch (e) {
          log.stderr('Warning: failed to restore tool/flutter-sdk: $e');
        }
      }
    }
  }

  int _approxBisectSteps(int commitCount) {
    if (commitCount <= 1) return 1;
    return commitCount.bitLength;
  }

  String _candidateRestoreRef(DevToolsRepo repo) {
    final versionStr = repo.readFile(Uri.parse('flutter-candidate.txt')).trim();
    if (_flutterPreReleaseTagRegExp.hasMatch(versionStr)) {
      return 'tags/$versionStr';
    }
    return versionStr;
  }

  Future<void> _ensureFlutterSdk(
    DevToolsRepo repo,
    ProcessManager processManager,
    Logger log,
  ) async {
    final sdkPath = repo.toolFlutterSdkPath;
    final gitLongFilesCommand = CliCommand.git([
      'config',
      'core.longpaths',
      'true',
    ]);

    if (Directory(sdkPath).existsSync()) {
      log.stdout('Using Flutter SDK at $sdkPath');
      try {
        await processManager.runAll(
          commands: [
            gitLongFilesCommand,
            CliCommand.git(['fetch']),
          ],
          workingDirectory: sdkPath,
        );
      } catch (e) {
        log.stderr('Warning: failed to fetch latest Flutter history: $e');
      }
      return;
    }

    log.stdout('Cloning Flutter into $sdkPath');
    await processManager.runProcess(
      CliCommand.git([
        'clone',
        '--no-checkout',
        'https://github.com/flutter/flutter',
        repo.sdkDirectoryName,
      ]),
      workingDirectory: repo.toolDirectoryPath,
    );
    await processManager.runProcess(
      gitLongFilesCommand,
      workingDirectory: sdkPath,
    );
  }

  Future<String> _revParse(
    ProcessManager processManager,
    String sdkPath,
    String ref,
  ) async {
    final result = await processManager.runProcess(
      CliCommand.git(['rev-parse', '--verify', ref]),
      workingDirectory: sdkPath,
    );
    return result.stdout.trim();
  }

  Future<bool> _isAncestor(
    ProcessManager processManager,
    String sdkPath, {
    required String ancestor,
    required String descendant,
  }) async {
    final result = await processManager.runProcess(
      CliCommand.git([
        'merge-base',
        '--is-ancestor',
        ancestor,
        descendant,
      ], throwOnException: false),
      workingDirectory: sdkPath,
    );
    return result.exitCode == 0;
  }

  /// Commits after [fromSha] up to and including [toSha], oldest first.
  Future<List<String>> _commitsBetween(
    ProcessManager processManager,
    String sdkPath, {
    required String fromSha,
    required String toSha,
  }) async {
    final result = await processManager.runProcess(
      CliCommand.git([
        'rev-list',
        '--ancestry-path',
        '--reverse',
        '$fromSha..$toSha',
      ]),
      workingDirectory: sdkPath,
    );
    return result.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> _checkoutFlutter(
    ProcessManager processManager,
    String sdkPath,
    String ref,
  ) async {
    await processManager.runProcess(
      CliCommand.git(['checkout', ref, '-f']),
      workingDirectory: sdkPath,
    );
    await processManager.runProcess(
      CliCommand(
        path.join(sdkPath, 'bin', FlutterSdk.flutterExecutableName),
        ['--version'],
        throwOnException: false,
      ),
      workingDirectory: sdkPath,
    );
  }

  Future<bool> _runTest(
    ProcessManager processManager, {
    required String sdkPath,
    required String packageDir,
    required String testPath,
    required Logger log,
  }) async {
    final result = await processManager.runProcess(
      CliCommand(
        path.join(sdkPath, 'bin', FlutterSdk.flutterExecutableName),
        ['test', testPath],
        throwOnException: false,
      ),
      workingDirectory: packageDir,
    );

    if (result.exitCode != 0) {
      final combined = '${result.stdout}\n${result.stderr}'.trim();
      final lines = combined.split('\n');
      final tail = lines.length <= 50
          ? lines
          : lines.sublist(lines.length - 50);
      log.stdout('--- test output (last ${tail.length} lines) ---');
      for (final line in tail) {
        log.stdout(line);
      }
      log.stdout('--- end test output ---');
    }

    return result.exitCode == 0;
  }

  Future<String> _commitSubject(
    ProcessManager processManager,
    String sdkPath,
    String sha,
  ) async {
    final result = await processManager.runProcess(
      CliCommand.git([
        'log',
        '-1',
        '--format=%s',
        sha,
      ], throwOnException: false),
      workingDirectory: sdkPath,
    );
    return result.stdout.trim();
  }
}
