// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:args/command_runner.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

const _pubGetFlag = 'pub-get';
const _upgradeFlag = 'upgrade';

class GenerateCodeCommand extends Command {
  GenerateCodeCommand() {
    argParser
      ..addFlag(
        _pubGetFlag,
        defaultsTo: true,
        negatable: true,
        help:
            'Run pub get on the DevTools packages before performing the code generation.',
      )
      ..addFlag(
        _upgradeFlag,
        negatable: false,
        help:
            'Run pub upgrade on the DevTools packages before performing the code generation.',
      );
  }

  @override
  String get name => 'generate-code';

  @override
  String get description =>
      'Performs code generation by running `build_runner build` for required packages.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();

    Future<void> runOverPackages(
      CliCommand command, {
      String? commandDescription,
    }) async {
      for (final packageName in ['devtools_app', 'devtools_test']) {
        if (commandDescription != null) {
          print('Running $commandDescription for $packageName...');
        }
        final directoryPath = path.join(repo.repoPath, 'packages', packageName);
        await processManager.runProcess(
          command,
          workingDirectory: directoryPath,
        );
      }
    }

    await runOverPackages(
      CliCommand.git(['clean', '-xfd', '.']),
      commandDescription: 'git clean',
    );

    final pubGet = argResults![_pubGetFlag] as bool;
    final upgrade = argResults![_upgradeFlag] as bool;
    if (pubGet) {
      await processManager.runProcess(
        CliCommand.tool(['pub-get', '--only-main', if (upgrade) '--upgrade']),
      );
    }

    await runOverPackages(
      CliCommand.dart([
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ]),
      commandDescription: 'build_runner build',
    );

    // Format the generated code so that the dart format check does not fail on
    // the CI.
    await processManager.runProcess(
      CliCommand.dart(['format', path.join('test', 'test_infra', 'scenes')]),
      workingDirectory: repo.devtoolsAppDirectoryPath,
    );
    await processManager.runProcess(
      CliCommand.dart([
        'format',
        path.join('lib', 'src', 'mocks', 'generated.mocks.dart'),
      ]),
      workingDirectory: path.join(repo.repoPath, 'packages', 'devtools_test'),
    );
  }
}
