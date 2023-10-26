// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

const _argCommit = 'commit';

/// This command updates the "devtools_rev" hash in the Dart SDK DEPS file with
/// the provided commit hash, and creates a Gerrit CL for review.
///
/// This hash is the ID for a DevTools build stored in CIPD, which is
/// automatically built and uploaded to CIPD on each DevTools commit.
///
/// To run this script:
/// `devtools_tool update-sdk-deps -c <commit-hash>`
class UpdateDartSdkDepsCommand extends Command {
  UpdateDartSdkDepsCommand() {
    argParser.addOption(
      _argCommit,
      abbr: 'c',
      help: 'The DevTools commit hash to release into the Dart SDK.',
      mandatory: true,
    );
  }
  @override
  String get name => 'update-sdk-deps';

  @override
  String get description =>
      'Updates the "devtools_rev" hash in the Dart SDK DEPS file with the '
      'provided commit hash, and creates a Gerrit CL for review';

  @override
  Future run() async {
    final commit = argResults![_argCommit];
    final dartSdkLocation = localDartSdkLocation();
    final processManager = ProcessManager();

    print('Preparing a local Dart SDK branch...');
    await DartSdkHelper.fetchAndCheckoutMaster(processManager);
    await processManager.runAll(
      workingDirectory: dartSdkLocation,
      additionalErrorMessage: DartSdkHelper.commandDebugMessage,
      commands: [
        CliCommand.git(
          'branch -D devtools-$commit',
          throwOnException: false,
        ),
        CliCommand.git('new-branch devtools-$commit'),
      ],
    );

    print('Updating the DEPS file with the new DevTools hash...');
    _writeToDepsFile(commit, dartSdkLocation);

    print('Committing the changes and creating a Gerrit CL...');
    await processManager.runAll(
      workingDirectory: dartSdkLocation,
      additionalErrorMessage: DartSdkHelper.commandDebugMessage,
      commands: [
        CliCommand.git('add .'),
        CliCommand.git("commit -m 'Update DevTools rev to $commit'"),
        CliCommand.git('cl upload -s -f'),
      ],
    );
  }

  void _writeToDepsFile(String commit, String localDartSdkLocation) {
    final depsFilePath = path.join(localDartSdkLocation, 'DEPS');
    final depsFile = File(depsFilePath);
    if (!depsFile.existsSync()) {
      throw Exception('Count not find SDK DEPS file at: $depsFilePath');
    }

    final devToolsRevMarker = '  "devtools_rev":';
    final newFileContent = StringBuffer();
    final lines = depsFile.readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith(devToolsRevMarker)) {
        newFileContent.writeln('$devToolsRevMarker "$commit",');
      } else {
        newFileContent.writeln(line);
      }
    }
    depsFile.writeAsStringSync(newFileContent.toString());
  }
}
