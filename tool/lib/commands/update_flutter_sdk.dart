// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';

import '../utils.dart';
import 'shared.dart';

final _flutterPreReleaseTagRegExp = RegExp(r'[0-9]+.[0-9]+.0-[0-9]+.0.pre');

/// This command updates the the Flutter SDK contained in the 'tool/' directory
/// to the latest Flutter candidate branch, as specified by the commit hash in
/// the flutter-candidate.txt file in the repository root.
///
/// When the '--update-on-path' flag is passed, the Flutter SDK that is on PATH
/// (your local flutter/flutter git checkout) will be updated as well.
///
/// To run this script:
/// `dt update-flutter-sdk [--update-on-path]`
class UpdateFlutterSdkCommand extends Command {
  UpdateFlutterSdkCommand() {
    argParser.addUpdateOnPathFlag();
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
    final updateOnPath =
        argResults![SharedCommandArgs.updateOnPath.flagName] as bool;
    final log = Logger.standard();
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();

    final String? flutterVersion;
    final versionStr = repo.readFile(Uri.parse('flutter-candidate.txt')).trim();
    // If the version string doesn't match the expected pattern for a
    // pre-release tag, then assume it's a commit hash:
    flutterVersion =
        _flutterPreReleaseTagRegExp.hasMatch(versionStr)
            ? 'tags/$versionStr'
            : versionStr;

    log.stdout('Updating to Flutter version from cache: $flutterVersion');

    final flutterSdkDirName = repo.sdkDirectoryName;
    final toolSdkPath = repo.toolFlutterSdkPath;

    // If the flag was set, update the SDK on PATH in addition to the
    // tool/flutter-sdk copy.
    if (updateOnPath) {
      final pathSdk = FlutterSdk.findFromPathEnvironmentVariable();
      log.stdout('Updating Flutter from PATH at ${pathSdk.sdkPath}');

      // Verify we have an upstream remote to pull from.
      await findRemote(
        processManager,
        remoteId: 'flutter/flutter.git',
        workingDirectory: pathSdk.sdkPath,
      );

      await processManager.runAll(
        commands: [
          CliCommand.git(['stash']),
          CliCommand.git(['fetch', 'upstream']),
          CliCommand.git(['checkout', 'upstream/master']),
          CliCommand.git(['reset', '--hard', 'upstream/master']),
          CliCommand.git(['checkout', flutterVersion, '-f']),
          CliCommand.flutter(['--version']),
        ],
        workingDirectory: pathSdk.sdkPath,
      );
      log.stdout('Finished updating Flutter from PATH at ${pathSdk.sdkPath}');
    }

    // Next, update (or clone) the tool/flutter-sdk copy.
    if (Directory(toolSdkPath).existsSync()) {
      log.stdout('Updating Flutter at $toolSdkPath');
      await processManager.runAll(
        commands: [
          CliCommand.git(['fetch']),
          CliCommand.git(['checkout', flutterVersion, '-f']),
          CliCommand.flutter(['--version']),
        ],
        workingDirectory: toolSdkPath,
      );
    } else {
      log.stdout('Cloning Flutter into $toolSdkPath');
      await processManager.runProcess(
        CliCommand.git([
          'clone',
          'https://github.com/flutter/flutter',
          flutterSdkDirName,
        ]),
        workingDirectory: repo.toolDirectoryPath,
      );
      await processManager.runAll(
        commands: [
          CliCommand.git(['checkout', flutterVersion, '-f']),
          CliCommand.flutter(['--version']),
        ],
        workingDirectory: toolSdkPath,
      );
    }
    log.stdout('Finished updating Flutter at $toolSdkPath.');
  }
}
