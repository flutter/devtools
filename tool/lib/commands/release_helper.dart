// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/utils.dart';
import 'package:io/io.dart';

class ReleaseHelperCommand extends Command {
  ReleaseHelperCommand() {
    argParser.addFlag(
      'use-current-branch',
      negatable: false,
      help:
          'Uses the current branch as the base for the release, instead of a fresh copy of master. For use when developing.',
    );
  }
  @override
  String get description =>
      'Creates a release version of devtools from the master branch, and pushes up a draft PR.';

  @override
  String get name => 'release-helper';

  @override
  FutureOr? run() async {
    final processManager = ProcessManager();

    final useCurrentBranch = argResults!['use-current-branch']!;
    final currentBranchResult = await processManager.runProcess(
      CliCommand.git(cmd: 'rev-parse --abbrev-ref HEAD'),
    );
    final initialBranch = currentBranchResult.stdout.trim();
    String? releaseBranch;

    try {
      Directory.current = pathFromRepoRoot("");
      final remoteUpstream = await findRemote(
        processManager,
        remoteId: 'flutter/devtools.git',
      );

      final gitStatusResult = await processManager.runProcess(
        CliCommand.git(cmd: 'status -s'),
      );
      final gitStatus = gitStatusResult.stdout;
      if (gitStatus.isNotEmpty) {
        throw "Error: Make sure your working directory is clean before running the helper";
      }

      releaseBranch =
          'release_helper_branch_${DateTime.now().millisecondsSinceEpoch}';

      if (!useCurrentBranch) {
        print("Preparing the release branch.");
        await processManager.runProcess(
          CliCommand.git(cmd: 'fetch $remoteUpstream master'),
        );
      }

      await processManager.runProcess(
        CliCommand.git(
          cmd: 'checkout -b $releaseBranch'
              '${useCurrentBranch ? '' : ' $remoteUpstream/master'}',
        ),
      );

      print("Ensuring ./tool packages are ready.");
      Directory.current = pathFromRepoRoot("tool");
      await processManager.runProcess(
        CliCommand.from(
          'dart',
          ['pub', 'get'],
        ),
        workingDirectory: pathFromRepoRoot("tool"),
      );

      print("Setting the release version.");
      await processManager.runProcess(
        CliCommand.tool('update-version auto --type release'),
        workingDirectory: pathFromRepoRoot("tool"),
      );

      final getNewVersionResult = await processManager.runProcess(
        CliCommand.tool('update-version current-version'),
      );

      final newVersion = getNewVersionResult.stdout.trim();

      final commitMessage = "Prepare for release $newVersion";

      await processManager.runAll(
        commands: [
          CliCommand.git(args: ['commit', '-a', '-m', commitMessage]),
          CliCommand.git(cmd: 'push -u $remoteUpstream $releaseBranch'),
        ],
      );

      print('Creating the PR.');
      final prURL = await processManager.runProcess(
        CliCommand.from('gh', [
          'pr',
          'create',
          '--repo',
          'flutter/devtools',
          '--draft',
          '--title',
          commitMessage,
          '--fill',
        ]),
      );

      print('Your Draft release PR can be found at: ${prURL.stdout.trim()}');
      print('DONE');
      print(
        'Build, run and test this release using: `devtools_tool serve`',
      );
    } catch (e) {
      print(e);

      // try to bring the caller back to their original branch
      await processManager.runProcess(
        CliCommand.git(cmd: 'checkout $initialBranch'),
      );

      // try to clean up the temporary branch we made
      if (releaseBranch != null) {
        await Process.run('git', [
          'branch',
          '-D',
          releaseBranch,
        ]);
      }
    }
  }
}
