import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:args/command_runner.dart';
import 'package:devtools_tool/utils.dart';

class ReleaseHelperCommand extends Command {
  @override
  // TODO: implement description
  String get description => 'Creates a draft PR for ';

  @override
  // TODO: implement name
  String get name => 'release-helper';

  @override
  FutureOr? run() async {
// #!/bin/bash -e
// DEVTOOLS_REMOTE=$(git remote -v | grep "flutter/devtools.git" | grep "(fetch)"| tail -n1 | cut -w -f1)

    // Change the CWD to the repo root
    Directory.current = pathFromRepoRoot("");

    final String devtoolsRemotes =
        (await Process.run('git', ['remote', '-v'])).stdout;
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
    final gitStatusResult = await Process.run('git', ['status', '-s']);
    if (gitStatusResult.stdout.isNotEmpty || gitStatusResult.exitCode != 0) {
      throw "Error: Make sure your working directory is clean before running the helper";
    }

// echo "Getting a fresh copy of master"
// echo
// MASTER="tmp_master_$(date +%s)"
// git fetch $DEVTOOLS_REMOTE master
// git checkout -b $MASTER $DEVTOOLS_REMOTE/master
    final uniqueBranch =
        '_release_helper_master_${DateTime.now().millisecondsSinceEpoch}';
    print(uniqueBranch);
    Process.run('git', ['fetch', remoteOrigin, 'master']);
    Process.run('git', [
      'checkout',
      '-b',
      uniqueBranch,
      '$remoteOrigin/master',
    ]);

// RELEASE_BRANCH="clean_release_$(date +%s)"
// git checkout -b "$RELEASE_BRANCH"
    final releaseBranch =
        '_release_helper_release_${DateTime.now().millisecondsSinceEpoch}';
    Process.run('git', ['checkout', '-b', releaseBranch]);

// echo "Ensuring ./tool packages are ready"
// echo
// dart pub get
    Directory.current = pathFromRepoRoot("tool");
    Process.run('dart', ['pub', 'get']);

// cd ..

// ORIGINAL_VERSION=$(dart tool/update_version.dart current-version)
    final currentVersionResult = await Process.run('dart', [
      'tool/update_version.dart',
      'current-version',
    ]);
    if (currentVersionResult.exitCode != 0) {
      throw "Error: failed to get current version";
    }
    final originalVersion = currentVersionResult.stdout;

// echo "Setting the release version"
// echo
// dart tool/update_version.dart auto --type release
    final createReleaseResult = await Process.run('dart', [
      'tool/update_version.dart',
      'auto',
      '--type',
      'release',
    ]);
    if (createReleaseResult.exitCode != 0) {
      throw "Error: failed to create release";
    }

// NEW_VERSION=$(dart tool/update_version.dart current-version)
    final getNewVersionResult = await Process.run('dart', [
      'tool/update_version.dart',
      'current-version',
    ]);
    if (getNewVersionResult.exitCode != 0) {
      throw "Error: failed to get version after creating release";
    }
    final newVersion = getNewVersionResult.stdout;

// COMMIT_MESSAGE="Releasing from $ORIGINAL_VERSION to $NEW_VERSION"
    final commitMessage = "Releasing from $originalVersion to $newVersion";

// # Stage the file, commit and push
// git commit -a -m "$COMMIT_MESSAGE"
    final commitResult = await Process.run('git', [
      'commit',
      '-a',
      '-m',
      commitMessage,
    ]);
    if (commitResult.exitCode != 0) {
      throw "Error: failed to commit";
    }

// git push -u $DEVTOOLS_REMOTE $RELEASE_BRANCH
    final pushResult = await Process.run('git', [
      'push',
      '-u',
      remoteOrigin,
      releaseBranch,
    ]);

    if (pushResult.exitCode != 0) {
      throw "Error: failed to push results";
    }

// echo "$0: Creating the PR"
// echo
    print('Creating the PR');
// PR_URL=$(gh pr create --repo flutter/devtools --draft --title "$COMMIT_MESSAGE" --fill)
    final createPRResult = await Process.run('gh', [
      'pr',
      'create',
      '--repo',
      'flutter/devtools',
      '--draft',
      '--title',
      commitMessage,
      '--fill',
    ]);
    if (createPRResult.exitCode != 0) {
      throw "Error: failed to create PR";
    }
    final prURL = createPRResult.stdout;

// echo "$0: Updating your flutter version to the most recent candidate."
// echo
// ./tool/update_flutter_sdk.sh --local
    final updateFlutterResult = await Process.run(
        path
            .join(
              '.',
              'tool',
              'update_flutter_sdk.sh',
            )
            .toString(),
        ['--local']);
    if (updateFlutterResult.exitCode != 0) {
      throw "Error: failed to update the flutter sdk";
    }

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
