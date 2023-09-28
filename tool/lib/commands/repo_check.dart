// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';

import '../model.dart';

class RepoCheckCommand extends Command {
  @override
  String get name => 'repo-check';

  @override
  String get description => 'Validate properties of the repo source code.';

  @override
  Future run() async {
    final repo = DevToolsRepo.requireInstance();
    print('DevTools repo at ${repo.repoPath}.');

    final checks = <Check>[
      DevToolsVersionCheck(),
    ];

    print('\nPerforming checks...');

    int failureCount = 0;

    for (var check in checks) {
      print('\nchecking ${check.name}:');

      try {
        await check.performCheck(repo);

        print('  check successful');
      } catch (e) {
        failureCount++;

        print('  failed: $e');
      }
    }

    return failureCount == 0 ? 0 : 1;
  }
}

abstract class Check {
  String get name;

  // Throw if the check fails.
  Future<void> performCheck(DevToolsRepo repo);
}

class DevToolsVersionCheck extends Check {
  @override
  String get name => 'devtools version';

  @override
  Future<void> performCheck(DevToolsRepo repo) {
    // TODO(devoncarew): Update this to use a package to parse the pubspec file;
    //                   https://pub.dev/packages/pubspec.
    final pubspecContents = repo.readFile('packages/devtools_app/pubspec.yaml');
    final versionString = pubspecContents
        .split('\n')
        .firstWhere((line) => line.startsWith('version:'));
    final pubspecVersion = versionString.substring('version:'.length).trim();

    final dartFileContents =
        repo.readFile('packages/devtools_app/lib/devtools.dart');

    final regexp = RegExp(r"version = '(\S+)';");
    final match = regexp.firstMatch(dartFileContents);
    if (match == null) {
      throw 'Unable to parse the DevTools version from '
          'packages/devtools_app/lib/devtools.dart';
    }
    final dartVersion = match.group(1);

    if (pubspecVersion != dartVersion) {
      throw 'App version $dartVersion != pubspec version $pubspecVersion; '
          'these need to be kept in sync.';
    }

    print('  version $pubspecVersion');

    return Future.value();
  }
}
