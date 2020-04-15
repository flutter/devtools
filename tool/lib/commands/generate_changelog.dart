// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:args/command_runner.dart';

import '../model.dart';

/// Changelog generator.
///
/// Sample usage:
/// ```
///     $ dart tool/bin/repo_tool.dart generate-changelog
///     Current Devtools version is 0.2.3-dev1.  Retrieving the tagged commit with the closest version number to this version.
///     Getting the date of the tagged commit for v0.2.2.
///     Getting commits since 2020-02-29T01:14:12Z
///     Skipping commit marked to be ignored: Update goldens (#1800)
///     Incrementing version number
///     Incremented version number for the changelog from v0.2.2 to 0.2.3. Note that this is not inserted to any files other than changelog.
///     Wrote the following output to /Users/djshuckerow/Code/github.com/DaveShuckerow/devtools/packages/devtools/CHANGELOG.md:
///     ## 0.2.3 2020-04-15
///     * Fix timeline for change in Flutter engine thread name (#1821)
///     * Debugger state management cleanup (#1817)
///     ...
///
///     Please note that this script is intended to simplify the changelog writing process, not to completely replace it.
///     Please review the generated changelog and tune it by hand to make it easily legible.
/// ```
///
/// The command will write commits after the last tagged non-dev release
/// into the changelog file. It will ignore commits with names strictly matching
/// [ignoredCommitNames].  It will then add 1 to the build version number
/// (eg 0.2.2 -> 0.2.3) when it determines the next version number.
///
/// If pushing a `-dev` build or using a different version number, you can edit
/// this by hand.
class GenerateChangelogCommand extends Command {
  // You can authorize your access if you run into a github rate limit.
  // Don't check in your passwords or auth tokens.
  static const auth = '';

  /// Commit names to ignore in changelog generation.
  ///
  /// We will only check for exact matches on this, after trimming out the
  /// trailing commit number.
  static const ignoredCommitNames = [
    'update goldens',
    'Update Goldens',
    'Update goldens'
  ];

  @override
  String get name => 'generate-changelog';

  @override
  String get description =>
      'Generates a changelog of all commits since a given tag.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance();
    final devtoolsVersionFile =
        await File('${repo.repoPath}/packages/devtools_app/lib/devtools.dart')
            .readAsString();
    const versionDeclarationPrefix = 'const String version = \'';
    final versionDeclaration =
        devtoolsVersionFile.indexOf(versionDeclarationPrefix);
    final versionEnd = devtoolsVersionFile.indexOf('\';');
    final version = devtoolsVersionFile.substring(
        versionDeclaration + versionDeclarationPrefix.length, versionEnd);
    final List tags = jsonDecode((await http.get(
            Uri.https('${auth}api.github.com', '/repos/flutter/devtools/tags')))
        .body);

    print('Current Devtools version is $version.  Retrieving the tagged commit '
        'with the closest version number to this version.');
    bool isDevBuild(String tagName) => tagName.split('-').length > 1;
    String nameOf(tag) => tag['name'];
    var closestTag = tags.skipWhile((tag) => isDevBuild(nameOf(tag))).first;
    for (var tag in tags) {
      if (isDevBuild(nameOf(tag))) {
        // This was a dev build.
        continue;
      }
      final tagVersion = getVersion(nameOf(tag));
      final closestTagVersion =
          closestTag == null ? null : getVersion(nameOf(closestTag));
      // TODO(djshuckerow): The script does not process dev versioning, so
      // ignore if the version file reports a dev version.
      final versionFileVersion =
          isDevBuild(version) ? null : getVersion(version);
      if ((versionFileVersion == null || tagVersion < versionFileVersion) &&
          (closestTagVersion == null || tagVersion > closestTagVersion)) {
        closestTag = tag;
      }
    }

    print('Getting the date of the tagged commit for ${closestTag["name"]}.');
    final taggedCommit = jsonDecode((await http.get(Uri.https(
      '${auth}api.github.com',
      '/repos/flutter/devtools/commits/${closestTag["commit"]["sha"]}',
    )))
        .body);

    final commitDate = taggedCommit['commit']['author']['date'];
    print('getting commits since $commitDate');
    final uri = Uri.https(
      '${auth}api.github.com',
      '/repos/flutter/devtools/commits',
      {'since': commitDate},
    );
    final commits = jsonDecode((await http.get(uri)).body);
    final changes = <String>[];
    for (var commit in commits) {
      if (commit['sha'] == taggedCommit['sha']) continue;
      final message = commit['commit']['message'];
      if (_shouldSkip(commit['commit']['message'])) {
        print('Skipping commit marked to be ignored: $message');
        continue;
      }
      changes.add('* ' + _sanitize(commit['commit']['message']));
      // TODO(djshuckerow): modify the commit message to link to the commit.
    }

    print('Incrementing version number');
    // TODO(djshuckerow): Support overriding the nextVersionNumber with a flag.
    String nextVersionNumber = nameOf(closestTag).replaceFirst('v', '');
    final List parts = nextVersionNumber.split('.');
    parts[2] = '${int.parse(parts[2]) + 1}';
    nextVersionNumber = parts.join('.');
    print('Incremented version number for the changelog from '
        '${closestTag["name"]} to $nextVersionNumber. Note that this is not '
        'inserted to any files other than changelog.');
    final versionDate = DateTime.now().toIso8601String().split('T').first;
    final changelogFile =
        File('${repo.repoPath}/packages/devtools/CHANGELOG.md');
    final output = '## $nextVersionNumber '
            '$versionDate\n' +
        changes.join('\n') +
        '\n\n';
    await changelogFile.writeAsString(
      output + changelogFile.readAsStringSync(),
    );

    print('Wrote the following output to ${changelogFile.path}:\n$output');
    print('Please note that this script is intended to simplify the changelog '
        'writing process, not to completely replace it. Please review the '
        'generated changelog and tune it by hand to make it easily legible.');
  }

  String _sanitize(String message) {
    message = message.split('\n').first;
    final periodNumberIndex = message.lastIndexOf('. (#');
    if (periodNumberIndex == -1) return message;
    return message.replaceFirst('. (#', ' (#', periodNumberIndex);
  }

  bool _shouldSkip(String message) {
    message = message.split('\n').first;
    message = message.replaceAll(RegExp('\\(#\\d*\\)'), '').trim();
    return ignoredCommitNames.contains(message);
  }
}

/// Converts versions into a monotonically-increasing integer.
///
/// This is used to determine which version is the most recently-pushed
/// tagged commit. After finding this version, we take all commits pushed
/// after the tagged commit to release.
int getVersion(String versionNumber) {
  final nums = versionNumber.replaceFirst('v', '').split('.');
  return int.parse(nums[0]) * 1000000 +
      int.parse(nums[1]) * 1000 +
      int.parse(nums[2]);
}
