// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:args/command_runner.dart';

import '../model.dart';

class GenerateChangelogCommand extends Command {
  // You can authorize your access if you run into a github rate limit.
  // Don't check in your passwords or auth tokens.
  static const auth = '';
  @override
  String get name => 'generate-changelog';

  @override
  String get description =>
      'Generates a changelog of all commits since a given tag.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance();
    String devtoolsVersionFile =
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
    var closestTag = tags.first;
    for (var tag in tags) {
      if (tag['name'].split('-').length > 1) {
        // This was a dev build.
        continue;
      }
      if (getVersion(tag['name']) < getVersion(version) &&
          (closestTag == null ||
              getVersion(tag['name']) > getVersion(closestTag['name']))) {
        print('it is the closest tag');
        closestTag = tag;
      }
    }

    print('getting the date of the tagged commit for ${closestTag["name"]}.');
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
      changes.add('* ' + commit['commit']['message'].split('\n').first);
    }

    String nextVersionNumber = closestTag['name'].replaceFirst('v', '');
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
}

int getVersion(String versionNumber) {
  final nums = versionNumber.replaceFirst('v', '').split('.');
  return int.parse(nums[0]) * 1000000 +
      int.parse(nums[1]) * 1000 +
      int.parse(nums[2]);
}
