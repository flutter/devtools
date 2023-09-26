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
      CliCommand.from(
        'git',
        [
          'rev-parse',
          '--abbrev-ref',
          'HEAD',
        ],
      ),
    );
    final initialBranch = currentBranchResult.trim();
    String? releaseBranch;

    try {
      // Change the CWD to the repo root
      Directory.current = pathFromRepoRoot("");
      print("Finding a remote that points to flutter/devtools.git.");
      final String devtoolsRemotes = await processManager.runProcess(
        CliCommand.from(
          'git',
          ['remote', '-v'],
        ),
      );
      final remoteRegexp = RegExp(
        r'^(?<remote>\S+)\s+(?<path>\S+)\s+\((?<action>\S+)\)',
        multiLine: true,
      );
      final remoteRegexpResults = remoteRegexp.allMatches(devtoolsRemotes);
      final RegExpMatch devtoolsRemoteResult;

      try {
        devtoolsRemoteResult = remoteRegexpResults.firstWhere(
          (element) => RegExp(r'flutter/devtools.git$')
              .hasMatch(element.namedGroup('path')!),
        );
      } on StateError {
        throw "ERROR: Couldn't find a remote that points to flutter/devtools.git. Instead got: \n$devtoolsRemotes";
      }
      final remoteOrigin = devtoolsRemoteResult.namedGroup('remote')!;

      final gitStatus = await processManager.runProcess(
        CliCommand.from('git', ['status', '-s']),
      );
      if (gitStatus.isNotEmpty) {
        throw "Error: Make sure your working directory is clean before running the helper";
      }

      releaseBranch =
          'release_helper_branch_${DateTime.now().millisecondsSinceEpoch}';

      if (!useCurrentBranch) {
        print("Preparing the release branch.");
        await processManager.runProcess(
          CliCommand.from('git', ['fetch', remoteOrigin, 'master']),
        );
      }

      await processManager.runProcess(
        CliCommand.from('git', [
          'checkout',
          '-b',
          releaseBranch,
          ...(useCurrentBranch ? [] : ['$remoteOrigin/master']),
        ]),
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
        CliCommand.from('dart', [
          'run',
          'devtools_tool.dart',
          'update-version',
          'auto',
          '--type',
          'release',
        ]),
      );

      final getNewVersionResult = await processManager.runProcess(
        CliCommand.from('devtools_tool', [
          'update-version',
          'current-version',
        ]),
      );

      final newVersion = getNewVersionResult;

      final commitMessage = "Prepare for release $newVersion";

      await processManager.runAll(
        commands: [
          CliCommand.from('git', [
            'commit',
            '-a',
            '-m',
            commitMessage,
          ]),
          CliCommand.from('git', [
            'push',
            '-u',
            remoteOrigin,
            releaseBranch,
          ]),
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

      print('Your Draft release PR can be found at: $prURL');
      print('DONE');
      print(
        'Build, run and test this release using: `dart ./tool/build_e2e.dart`',
      );
    } catch (e) {
      print(e);

      // try to bring the caller back to their original branch
      await Process.run('git', ['checkout', initialBranch]);

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
