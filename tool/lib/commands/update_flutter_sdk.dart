// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

const _localFlag = 'local';
const _useCacheFlag = 'use-cache';

/// This command updates the the Flutter SDK contained in the 'tool/' directory
/// to the latest Flutter candidate branch.
///
/// When the '--local' flag is passed, your local flutter/flutter checkout will
/// be updated as well.
///
/// This command will use the Flutter version from the 'flutter-candidate.txt'
/// file in the repository root, unless the '--no-use-cache' flag is passed,
/// in which case it will run the 'tool/latest_flutter_candidate.sh' script to
/// fetch the latest version from upstream.
///
/// The version from 'flutter-candidate.txt' should be identical most of the
/// time since the GitHub workflow that updates this file runs twice per day.
///
/// To run this script:
/// `devtools_tool update-flutter-sdk [--local] [--no-use-cache]`
class UpdateFlutterSdkCommand extends Command {
  UpdateFlutterSdkCommand() {
    argParser
      ..addFlag(
        _localFlag,
        negatable: false,
        help: 'Update your local checkout of the Flutter SDK',
      )
      ..addFlag(
        _useCacheFlag,
        negatable: true,
        defaultsTo: true,
        help:
            'Use the cached Flutter version stored in "flutter-candidate.txt" '
            'instead of the latest version at '
            '"https://flutter.googlesource.com/mirrors/flutter/"',
      );
  }
  @override
  String get name => 'update-flutter-sdk';

  @override
  String get description =>
      'Updates the "devtools_rev" hash in the Dart SDK DEPS file with the '
      'provided commit hash, and creates a Gerrit CL for review';

  @override
  Future run() async {
    final updateLocalFlutter = argResults![_localFlag];
    final useCachedVersion = argResults![_useCacheFlag];
    final log = Logger.standard();

    // TODO(kenz): we can remove this if we can rewrite the
    // 'latest_flutter_candidate.sh' script as a Dart script, or if we instead
    // duplicate it as a Windows script (we may need this to be a non-Dart
    // script for execution on the bots before we have a Dart SDK available).
    if (Platform.isWindows && !useCachedVersion) {
      log.stderr(
        'On windows, you can only use the cached Flutter version from '
        '"flutter-candidate.txt". Please remove the "--no-use-cache" flag and '
        'try again.',
      );
      return 1;
    }

    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();

    late String flutterTag;
    if (useCachedVersion) {
      flutterTag =
          'tags/${repo.readFile(Uri.parse('flutter-candidate.txt')).trim()}';
    } else {
      flutterTag = (await processManager.runProcess(
        CliCommand('sh latest_flutter_candidate.sh'),
        workingDirectory: repo.toolDirectoryPath,
      ))
          .stdout
          .replaceFirst('refs/', '');
    }

    log.stdout(
      'Updating to Flutter version '
      '${useCachedVersion ? 'from cache' : 'from upstream'}: $flutterTag ',
    );

    if (updateLocalFlutter) {
      final sdk = FlutterSdk.getSdk();
      if (sdk == null) {
        print('Unable to locate a Flutter sdk.');
        return 1;
      }

      log.stdout('Updating local Flutter checkout...');

      // Verify we have an upstream remote to pull from.
      await findRemote(
        processManager,
        remoteId: 'flutter/flutter.git',
        workingDirectory: sdk.sdkPath,
      );

      await processManager.runAll(
        commands: [
          CliCommand.git('stash'),
          CliCommand.git('fetch upstream'),
          CliCommand.git('checkout upstream/master'),
          CliCommand.git('reset --hard upstream/master'),
          CliCommand.git('checkout $flutterTag -f'),
          CliCommand.flutter('--version'),
        ],
        workingDirectory: sdk.sdkPath,
      );
      log.stdout('Finished updating local Flutter checkout.');
    }

    final flutterSdkDirName = 'flutter-sdk';
    final toolSdkPath = path.join(
      repo.toolDirectoryPath,
      flutterSdkDirName,
    );
    final toolFlutterSdk = Directory.fromUri(Uri.file(toolSdkPath));
    log.stdout('Updating "$toolSdkPath" to branch $flutterTag');

    if (toolFlutterSdk.existsSync()) {
      log.stdout('"$toolSdkPath" directory already exists');
      await processManager.runAll(
        commands: [
          CliCommand.git('fetch'),
          CliCommand.git('checkout $flutterTag -f'),
          CliCommand.flutter('--version'),
        ],
        workingDirectory: toolFlutterSdk.path,
      );
    } else {
      log.stdout('"$toolSdkPath" directory does not exist - cloning it now');
      await processManager.runProcess(
        CliCommand.git(
          'clone https://github.com/flutter/flutter $flutterSdkDirName',
        ),
        workingDirectory: repo.toolDirectoryPath,
      );
      await processManager.runAll(
        commands: [
          CliCommand.git('checkout $flutterTag -f'),
          CliCommand.flutter('--version'),
        ],
        workingDirectory: toolFlutterSdk.path,
      );
    }

    log.stdout('Finished updating $toolSdkPath.');
  }
}
