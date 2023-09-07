import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/utils.dart';
import 'package:path/path.dart' as path;

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
  // TODO: implement description
  String get description => 'Creates a draft PR for ';

  @override
  // TODO: implement name
  String get name => 'release-helper';

  @override
  FutureOr? run() async {
    final useCurrentBranch = argResults!['use-current-branch']!;
// #!/bin/bash -e
// DEVTOOLS_REMOTE=$(git remote -v | grep "flutter/devtools.git" | grep "(fetch)"| tail -n1 | cut -w -f1)

    // Change the CWD to the repo root
    Directory.current = pathFromRepoRoot("");

    final String devtoolsRemotes =
        (await DevtoolsProcess.runOrThrow('git', ['remote', '-v'])).stdout;
    final remoteRegexp = RegExp(
      r'^(?<remote>\S+)\s+(?<path>\S+)\s+\((?<action>\S+)\)',
      multiLine: true,
    );
    final remoteRegexpResults = remoteRegexp.allMatches(devtoolsRemotes);
    final RegExpMatch devtoolsRemoteResult;
// if [ -z "$DEVTOOLS_REMOTE" ] ; then
//     echo "Couldn't find a remote that points to flutter/devtools.git"
//     exit 1
// fi
    try {
      devtoolsRemoteResult = remoteRegexpResults.firstWhere((element) =>
          RegExp(r'flutter/devtools.git$')
              .hasMatch(element.namedGroup('path')!));
    } on StateError {
      throw "ERROR: Couldn't find a remote that points to flutter/devtools git. Instead got: \n$devtoolsRemotes";
    }
    final remoteOrigin = devtoolsRemoteResult.namedGroup('remote')!;

// STATUS=$(git status -s)
// if [[ ! -z  "$STATUS" ]] ; then
//     echo "Make sure your working directory is clean before running the helper"
//     exit 1
// fi
    final gitStatusResult =
        await DevtoolsProcess.runOrThrow('git', ['status', '-s']);
    if (gitStatusResult.stdout.isNotEmpty) {
      throw "Error: Make sure your working directory is clean before running the helper";
    }
// echo "Getting a fresh copy of master"
// echo
// MASTER="tmp_master_$(date +%s)"
// git fetch $DEVTOOLS_REMOTE master
// git checkout -b $MASTER $DEVTOOLS_REMOTE/master

    final uniqueBranch =
        '_release_helper_master_${DateTime.now().millisecondsSinceEpoch}';

    if (!useCurrentBranch) {
      await DevtoolsProcess.runOrThrow(
          'git', ['fetch', remoteOrigin, 'master']);

      await DevtoolsProcess.runOrThrow('git', [
        'checkout',
        '-b',
        uniqueBranch,
        '$remoteOrigin/master',
      ]);
    }

// RELEASE_BRANCH="clean_release_$(date +%s)"
// git checkout -b "$RELEASE_BRANCH"
    final releaseBranch =
        '_release_helper_release_${DateTime.now().millisecondsSinceEpoch}';
    await DevtoolsProcess.runOrThrow('git', ['checkout', '-b', releaseBranch]);

// echo "Ensuring ./tool packages are ready"
// echo
// dart pub get
    print(pathFromRepoRoot("tool"));
    Directory.current = pathFromRepoRoot("tool");
    await DevtoolsProcess.runOrThrow('dart', ['pub', 'get']);

    Directory.current = pathFromRepoRoot("");

// ORIGINAL_VERSION=$(dart tool/update_version.dart current-version)
    final currentVersionResult = await DevtoolsProcess.runOrThrow('dart', [
      path.join('tool', 'update_version.dart').toString(),
      'current-version',
    ]);

    final originalVersion = currentVersionResult.stdout;

// echo "Setting the release version"
// echo
// dart tool/update_version.dart auto --type release
    await DevtoolsProcess.runOrThrow('dart', [
      'tool/update_version.dart',
      'auto',
      '--type',
      'release',
    ]);

// NEW_VERSION=$(dart tool/update_version.dart current-version)
    final getNewVersionResult = await DevtoolsProcess.runOrThrow('dart', [
      'tool/update_version.dart',
      'current-version',
    ]);

    final newVersion = getNewVersionResult.stdout;

// COMMIT_MESSAGE="Releasing from $ORIGINAL_VERSION to $NEW_VERSION"
    final commitMessage = "Releasing from $originalVersion to $newVersion";

// # Stage the file, commit and push
// git commit -a -m "$COMMIT_MESSAGE"
    await DevtoolsProcess.runOrThrow('git', [
      'commit',
      '-a',
      '-m',
      commitMessage,
    ]);

// git push -u $DEVTOOLS_REMOTE $RELEASE_BRANCH
    await DevtoolsProcess.runOrThrow('git', [
      'push',
      '-u',
      remoteOrigin,
      releaseBranch,
    ]);

// echo "$0: Creating the PR"
// echo
    print('Creating the PR');
// PR_URL=$(gh pr create --repo flutter/devtools --draft --title "$COMMIT_MESSAGE" --fill)
    final createPRResult = await DevtoolsProcess.runOrThrow('gh', [
      'pr',
      'create',
      '--repo',
      'flutter/devtools',
      '--draft',
      '--title',
      commitMessage,
      '--fill',
    ]);

    final prURL = createPRResult.stdout;

// echo "$0: Updating your flutter version to the most recent candidate."
// echo
// ./tool/update_flutter_sdk.sh --local
    await DevtoolsProcess.runOrThrow(
        path
            .join(
              '.',
              'tool',
              'update_flutter_sdk.sh',
            )
            .toString(),
        ['--local']);

// echo "$0: Your Draft release PR can be found at: $PR_URL"
// echo
// echo "$0: DONE.
// echo "$0: Build, run and test this release using: 'dart ./tool/build_e2e.dart'"
    print('Your Draft release PR can be found at: $prURL');
    print('DONE');
    print(
      'Build, run and test this release using: `dart ./tool/build_e2e.dart`',
    );
  }
}
