// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../model.dart';

const versionArg = 'version';
const sinceArg = 'since-tag';

/// Changelog generator.
///
/// Sample usage:
/// ```
///   $dart tool/bin/repo_tool.dart generate-changelog
///   Retrieving the most recent tag...
///   Getting the date of the tagged commit for v2.4.0...
///   Adding entries to the changelog for all commits since 2021-07-08T16:51:57Z...
///   Skipping commit 9cfec998746f71bc533bd6617ae80f407560a952 because this is the commit of the previous tag
///   Incrementing version number...
///   Incremented version number for the changelog from 2.4.0 to 2.5.0. Note that this is not inserted to any files other than changelog.
///   Wrote the following output to /Users/kenzieschmoll/develop/devtools/packages/devtools/CHANGELOG.md:
///   ## 2.5.0
///   * Fix debug buttons layout overflow [#3224](https://github.com/flutter/devtools/pull/3224)
///   * Make return key submit connect form [#3228](https://github.com/flutter/devtools/pull/3228)
///   * Minor analysis updates to the repo [#3225](https://github.com/flutter/devtools/pull/3225)
///   * Always build devtools from a specified, specific sdk version [#3216](https://github.com/flutter/devtools/pull/3216)
///   ...
///
///   Please note that this script is intended to simplify the changelog writing process, not to completely replace it.
///   Please review the generated changelog and tune it by hand to make it easily legible.
/// ```
///
/// The command will write commits after the last tagged non-dev / non-dot
/// release into the changelog file. It will ignore commits with names strictly
/// matching [lowercaseIgnoredCommitNames].  It will then add 1 to the minor
/// version number (eg 2.4.2 => 2.5.0).
///
/// If `--version` is specified from the command
/// (e.g. dart tool/bin/repo_tool.dart generate-changelog --version=2.5.2), this
/// version number will be used for the CHANGELOG entry.
///
/// If `--since-tag` is specified from the command
/// (e.g. dart tool/bin/repo_tool.dart generate-changelog --version=2.5.2), this
/// tag version will be used as the lower bound for commit history instead of
/// using the most recent tagged version as the lower bound.
class GenerateChangelogCommand extends Command {
  GenerateChangelogCommand() {
    argParser
      ..addOption(
        versionArg,
        help: 'Specify the target changelog version',
      )
      ..addOption(
        sinceArg,
        help: 'Specify the name of the tag to mark the lower bound',
      );
  }

  // You can authorize your access if you run into a github rate limit.
  // Don't check in your passwords or auth tokens.
  static const auth = '';

  /// Commit names to ignore in changelog generation.
  ///
  /// We will only check for exact matches on this, after trimming out the
  /// trailing commit number.
  static const lowercaseIgnoredCommitNames = [
    'update goldens',
    'updated goldens',
  ];

  @override
  String get name => 'generate-changelog';

  @override
  String get description =>
      'Generates a changelog of all commits since a given tag.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance()!;
    String? nextVersion = argResults?[versionArg];
    final sinceTag = argResults?[sinceArg];

    final List<Map<String, dynamic>> tags = (jsonDecode((await http.get(
                Uri.https(
                    '${auth}api.github.com', '/repos/flutter/devtools/tags')))
            .body) as List)
        .cast<Map<String, dynamic>>();

    bool isDevBuild(String tagName) => tagName.contains('dev');
    bool isCherryPickRelease(String tagName) => tagName.contains('+');
    String nameOf(tag) => tag['name'];

    Map<String, dynamic>? closestTag;
    if (sinceTag != null) {
      print('Attempting to find tag with name $sinceTag, '
          'as specified by --$sinceArg...');
      closestTag = tags.firstWhere((tag) => nameOf(tag) == sinceTag);
    } else {
      print('Retrieving the most recent tag...');
      closestTag = tags.skipWhile((tag) {
        final skip =
            isDevBuild(nameOf(tag)) || isCherryPickRelease(nameOf(tag));
        return skip;
      }).first;
    }

    final commitInfo = closestTag['commit'] as Map<String, dynamic>;
    print('Getting the date of the tagged commit for ${closestTag['name']}...');
    final taggedCommit = jsonDecode((await http.get(Uri.https(
      '${auth}api.github.com',
      '/repos/flutter/devtools/commits/${commitInfo['sha']}',
    )))
        .body);

    final commitDate = taggedCommit['commit']['author']['date'];
    print(
        'Adding entries to the changelog for all commits since $commitDate...');

    // TODO(kenz): handle cases where there are more than 100 commits.
    final uri = Uri.https(
      '${auth}api.github.com',
      '/repos/flutter/devtools/commits',
      {
        'since': commitDate,
        'per_page': '100',
      },
    );
    final commits = jsonDecode((await http.get(uri)).body);
    final changes = <String>[];
    for (var commit in commits) {
      if (commit['sha'] == taggedCommit['sha']) {
        print(
            'Skipping commit ${commit['sha']} because this is the commit of the previous tag');
        continue;
      }
      final message = commit['commit']['message'];
      if (_shouldSkip(commit['commit']['message'])) {
        print('Skipping commit marked to be ignored: $message');
        continue;
      }
      final entry = '* ' + _sanitize(commit['commit']['message']);
      changes.add(entry);
    }

    if (nextVersion != null) {
      print('Using specified version $nextVersion...');
    } else {
      print('Incrementing version number...');
      final currentVersion = nameOf(closestTag).replaceFirst('v', '');
      // Increment the minor version by 1 and reset the patch version to 0
      // (e.g. 2.4.2 => 2.5.0)
      final List<String> parts = currentVersion.split('.');
      parts[1] = '${int.parse(parts[1]) + 1}';
      parts[2] = '0';
      nextVersion = parts.join('.');
      print('Incremented version number for the changelog from '
          '$currentVersion to $nextVersion. Note that this is not '
          'inserted to any files other than changelog.');
    }

    final changelogFile = File('${repo.repoPath}/CHANGELOG.md');
    final output = '## $nextVersion\n' + changes.join('\n') + '\n\n';
    await changelogFile.writeAsString(
      output + changelogFile.readAsStringSync(),
    );

    print('Wrote the following output to ${changelogFile.path}:\n$output');
    print('Please note that this script is intended to simplify the changelog '
        'writing process, not to completely replace it. Please review the '
        'generated changelog and tune it by hand to make it easily legible.');
  }

  String _sanitize(String message) {
    try {
      var modifiedMessage = message.split('\n').first;
      modifiedMessage = modifiedMessage.substring(0, 1).toUpperCase() +
          modifiedMessage.substring(1, modifiedMessage.length);
      const prPrefix = '(#';
      final periodNumberIndex = modifiedMessage.lastIndexOf('. $prPrefix');
      if (periodNumberIndex != -1) {
        modifiedMessage = modifiedMessage.replaceFirst(
          '. $prPrefix',
          prPrefix,
          periodNumberIndex,
        );
      }
      final prIndex = modifiedMessage.indexOf(prPrefix);
      final endPrIndexExclusive = modifiedMessage.lastIndexOf(')');
      final pr = modifiedMessage.substring(
        prIndex + prPrefix.length,
        endPrIndexExclusive,
      );
      return modifiedMessage.substring(0, prIndex).trim() +
          ' [#$pr](https://github.com/flutter/devtools/pull/$pr)';
    } catch (_) {
      return '# Something went wrong. Please input this CHANGELOG entry '
          'manually: "$message"';
    }
  }

  bool _shouldSkip(String message) {
    message = message.split('\n').first;
    message = message.replaceAll(RegExp('\\(#\\d*\\)'), '').trim();
    for (final ignore in lowercaseIgnoredCommitNames) {
      if (message.toLowerCase().contains(ignore)) {
        return true;
      }
    }
    return false;
  }
}
