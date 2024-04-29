// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:devtools_tool/model.dart';
import 'package:devtools_tool/utils.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

class ReleaseHelperCommand extends Command {
  ReleaseHelperCommand() {
    argParser.addFlag(
      _debugFlag,
      negatable: false,
      help:
          'Whether to run this script for development purposes. This disables '
          'some checks like requiring no local changes or checking out a fresh '
          'copy of the master branch.',
    );
  }

  static const _debugFlag = 'debug';

  @override
  String get description =>
      'Creates a release version of devtools from the master branch, and pushes up a draft PR.';

  @override
  String get name => 'release-helper';

  @override
  FutureOr? run() async {
    final log = Logger.standard();
    final processManager = ProcessManager();

    final debug = argResults![_debugFlag] as bool;
    final currentBranchResult = await processManager.runProcess(
      CliCommand.git(['rev-parse', '--abbrev-ref', 'HEAD']),
    );
    final initialBranch = currentBranchResult.stdout.trim();
    String? releaseBranch;

    bool committedLocalChanges = false;
    try {
      Directory.current = pathFromRepoRoot("");
      final remoteUpstream = await findRemote(
        processManager,
        remoteId: 'flutter/devtools.git',
      );

      try {
        await _ensureNoLocalChanges(processManager);
      } catch (_) {
        if (debug) {
          // Temporarily commit any local changes to this script to the current
          // branch. This commit will be reset at the end of the script.
          final pathToReleaseHelperScript = Uri.parse(
            p.posix.join(
              DevToolsRepo.getInstance().toolDirectoryPath,
              'lib',
              'commands',
              'release_helper.dart',
            ),
          ).toFilePath();
          await processManager.runProcess(
            CliCommand.git(['add', pathToReleaseHelperScript]),
          );
          await processManager.runProcess(
            CliCommand.git(['commit', '-m', 'temp']),
          );
          committedLocalChanges = true;

          // Try again now that we've committed local changes to this script.
          await _ensureNoLocalChanges(processManager);
        } else {
          rethrow;
        }
      }

      log.stdout("Preparing the release branch.");
      await processManager.runProcess(
        CliCommand.git(['fetch', remoteUpstream, 'master']),
      );

      releaseBranch =
          'release_helper_branch_${DateTime.now().millisecondsSinceEpoch}';
      await processManager.runProcess(
        CliCommand.git(
          [
            'checkout',
            '-b',
            releaseBranch,
            '$remoteUpstream/master',
          ],
        ),
      );

      log.stdout("Ensuring ./tool package is ready.");
      Directory.current = pathFromRepoRoot("tool");
      await processManager.runProcess(
        CliCommand.dart(['pub', 'get']),
        workingDirectory: pathFromRepoRoot("tool"),
      );

      log.stdout("Setting the release version.");
      await processManager.runProcess(
        CliCommand.tool(['update-version', 'auto', '--type', 'release']),
      );

      final getNewVersionResult = await processManager.runProcess(
        CliCommand.tool(
          ['update-version', 'current-version'],
        ),
      );

      final newVersion = getNewVersionResult.stdout.split('\n').last.trim();

      log.stdout(getNewVersionResult.stdout.split('\n').toString());

      final commitMessage = "Prepare for release $newVersion";

      await processManager.runAll(
        commands: [
          CliCommand.git(['commit', '-a', '-m', commitMessage]),
          CliCommand.git(['push', '-u', remoteUpstream, releaseBranch]),
        ],
      );

      log.stdout('Creating the PR.');
      final prURL = await processManager.runProcess(
        CliCommand(
          'gh',
          [
            'pr',
            'create',
            '--repo',
            'flutter/devtools',
            '--draft',
            '--title',
            commitMessage,
            '--fill',
          ],
        ),
      );

      log.stdout(
          'Your Draft release PR can be found at: ${prURL.stdout.trim()}');
      log.stdout('DONE');
      log.stdout(
        'Build, run and test this release using: `devtools_tool serve`',
      );
    } catch (e) {
      log.stderr(e.toString());

      // try to bring the caller back to their original branch
      await processManager.runProcess(
        CliCommand.git(['checkout', initialBranch]),
      );

      // try to clean up the temporary branch we made
      if (releaseBranch != null) {
        await Process.run('git', [
          'branch',
          '-D',
          releaseBranch,
        ]);
      }
    } finally {
      if (committedLocalChanges) {
        // Bring back the local changes we committed to the initial branch.
        await processManager.runProcess(
          CliCommand.git(['reset', '--soft', 'HEAD~1']),
        );
      }
    }
  }

  Future<void> _ensureNoLocalChanges(ProcessManager processManager) async {
    final gitStatusResult = await processManager.runProcess(
      CliCommand.git(['status', '-s']),
    );
    final gitStatus = gitStatusResult.stdout;
    if (gitStatus.isNotEmpty) {
      throw Exception(
        'Error: Make sure your working directory does not have any local '
        'changes before running the release_helper command.',
      );
    }
  }
}
