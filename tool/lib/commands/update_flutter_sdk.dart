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

const _useCacheFlag = 'use-cache';

/// This command updates the the Flutter SDK contained in the 'tool/' directory
/// to the latest Flutter candidate branch.
///
/// When the '--from-path' flag is passed, the Flutter SDK that is on PATH (your
/// local flutter/flutter git checkout) will be updated as well.
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
/// `devtools_tool update-flutter-sdk [--from-path] [--no-use-cache]`
class UpdateFlutterSdkCommand extends Command {
  UpdateFlutterSdkCommand() {
    argParser.addFlag(
      _useCacheFlag,
      negatable: true,
      defaultsTo: true,
      help: 'Update the Flutter SDK(s) to the cached Flutter version stored '
          'in "flutter-candidate.txt" instead of the latest version at '
          '"https://flutter.googlesource.com/mirrors/flutter/"',
    );
  }
  @override
  String get name => 'update-flutter-sdk';

  @override
  String get description =>
      'Updates the the Flutter SDK contained in the \'tool/\' directory to the '
      'latest Flutter candidate branch. Optionally, can also update the Flutter'
      'SDK that is on PATH (your local flutter/flutter git checkout).';

  @override
  Future run() async {
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
          .replaceFirst('refs/', '')
          .trim();
    }

    log.stdout(
      'Updating to Flutter version '
      '${useCachedVersion ? 'from cache' : 'from upstream'}: $flutterTag ',
    );

    final sdk = FlutterSdk.current;
    final flutterSdkDirName = 'flutter-sdk';
    final toolSdkPath = path.join(repo.toolDirectoryPath, flutterSdkDirName);
    final toolFlutterSdkDirectory = Directory(toolSdkPath);

    // Check if the Flutter SDK we're using is not the local tool/flutter-sdk
    // one and if so update that too.
    //
    // Check paths case-insensitively because of potential differences like
    // windows drive letters.
    if (sdk.sdkPath.toLowerCase() !=
        toolFlutterSdkDirectory.path.toLowerCase()) {
      log.stdout(
        'Current Flutter SDK is not tool/flutter-sdk, updating repository '
        'at ${sdk.sdkPath}',
      );

      // Verify we have an upstream remote to pull from.
      await findRemote(
        processManager,
        remoteId: 'flutter/flutter.git',
        workingDirectory: FlutterSdk.current.sdkPath,
      );

      await processManager.runAll(
        commands: [
          CliCommand.git(cmd: 'stash'),
          CliCommand.git(cmd: 'fetch upstream'),
          CliCommand.git(cmd: 'checkout upstream/master'),
          CliCommand.git(cmd: 'reset --hard upstream/master'),
          CliCommand.git(cmd: 'checkout $flutterTag -f'),
          CliCommand.flutter('--version'),
        ],
        workingDirectory: FlutterSdk.current.sdkPath,
      );
      log.stdout('Finished updating local flutter/flutter repository.');
    }

    // Next, update (or clone) the tool/flutter-sdk copy.
    log.stdout('Updating "$toolSdkPath" to branch $flutterTag');
    if (toolFlutterSdkDirectory.existsSync()) {
      log.stdout(
        '"$toolSdkPath" directory already exists. Fetching $flutterTag from GitHub.',
      );
      await processManager.runAll(
        commands: [
          CliCommand.git(cmd: 'fetch'),
          CliCommand.git(cmd: 'checkout $flutterTag -f'),
          CliCommand.flutter('--version'),
        ],
        workingDirectory: toolFlutterSdkDirectory.path,
      );
    } else {
      log.stdout('Cloning flutter/flutter into "$toolSdkPath" directory.');
      await processManager.runProcess(
        CliCommand.git(
          cmd: 'clone https://github.com/flutter/flutter $flutterSdkDirName',
        ),
        workingDirectory: repo.toolDirectoryPath,
      );
      await processManager.runAll(
        commands: [
          CliCommand.git(cmd: 'checkout $flutterTag -f'),
          CliCommand.flutter('--version'),
        ],
        workingDirectory: toolFlutterSdkDirectory.path,
      );
    }
    log.stdout('Finished updating $toolSdkPath.');
  }
}
