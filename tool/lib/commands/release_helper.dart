import 'dart:async';
import 'dart:io';

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
    final remoteOrigin = devtoolsRemoteResult.namedGroup('remote');

// STATUS=$(git status -s)
// if [[ ! -z  "$STATUS" ]] ; then
//     echo "Make sure your working directory is clean before running the helper"
//     exit 1
// fi
    final String gitStatus =
        (await Process.run('git', ['status', '-s'])).stdout;
    if (gitStatus.isNotEmpty) {
      throw "Error: Make sure your working directory is clean before running the helper";
    }

// echo "Getting a fresh copy of master"
// echo
// MASTER="tmp_master_$(date +%s)"
// git fetch $DEVTOOLS_REMOTE master
// git checkout -b $MASTER $DEVTOOLS_REMOTE/master

// RELEASE_BRANCH="clean_release_$(date +%s)"
// git checkout -b "$RELEASE_BRANCH"

// echo "Ensuring ./tool packages are ready"
// echo
// dart pub get

// cd ..

// ORIGINAL_VERSION=$(dart tool/update_version.dart current-version)

// echo "Setting the release version"
// echo
// dart tool/update_version.dart auto --type release

// NEW_VERSION=$(dart tool/update_version.dart current-version)

// COMMIT_MESSAGE="Releasing from $ORIGINAL_VERSION to $NEW_VERSION"

// # Stage the file, commit and push
// git commit -a -m "$COMMIT_MESSAGE"

// git push -u $DEVTOOLS_REMOTE $RELEASE_BRANCH

// echo "$0: Creating the PR"
// echo

// PR_URL=$(gh pr create --repo flutter/devtools --draft --title "$COMMIT_MESSAGE" --fill)

// echo "$0: Updating your flutter version to the most recent candidate."
// echo
// ./tool/update_flutter_sdk.sh --local

// echo "$0: Your Draft release PR can be found at: $PR_URL"
// echo
// echo "$0: DONE.
// echo "$0: Build, run and test this release using: 'dart ./tool/build_e2e.dart'"
  }
}
