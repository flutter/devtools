// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

const _useLocalFlutterFlag = 'use-local-flutter';
const _updatePerfettoFlag = 'update-perfetto';

class BuildReleaseCommand extends Command {
  BuildReleaseCommand() {
    argParser
      ..addFlag(
        _useLocalFlutterFlag,
        negatable: false,
        defaultsTo: false,
        help:
            'Whether to use the Flutter SDK on PATH instead of the Flutter SDK '
            'contained in the "tool/flutter-sdk" directory.',
      )
      ..addFlag(
        _updatePerfettoFlag,
        negatable: false,
        defaultsTo: false,
        help: 'Whether to update the Perfetto assets before building DevTools.',
      );
  }

  @override
  String get name => 'build-release';

  @override
  String get description => 'Prepares a release build of DevTools.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();

    final useLocalFlutter = argResults![_useLocalFlutterFlag];
    final updatePerfetto = argResults![_updatePerfettoFlag];

    if (!useLocalFlutter) {
      logStatus('updating tool/flutter-sdk to the latest flutter candidate');
      await processManager.runProcess(CliCommand.tool('update-flutter-sdk'));
    }

    if (updatePerfetto) {
      logStatus('updating the bundled Perfetto assets');
      // TODO(kenz): call `devtools_tool update-perfetto` once the
      // tool/update_perfetto.sh script is converted to a Dart script.
    }

    logStatus('building DevTools in release mode');
    await processManager.runAll(
      commands: [
        CliCommand.flutter('clean'),
        CliCommand('rm -rf ${path.join('build', 'web')}'),
        CliCommand.tool('pub-get --only-main'),
        CliCommand.flutter(
          'build web --web-renderer canvaskit --pwa-strategy=offline-first'
          ' --release --no-tree-shake-icons',
        ),
      ],
      workingDirectory: repo.devtoolsAppDirectoryPath,
    );

    final canvaskitDir = Directory(
      path.join(repo.devtoolsAppDirectoryPath, 'build', 'web', 'canvaskit'),
    );
    for (final file in canvaskitDir.listSync()) {
      if (RegExp(r'canvaskit\..*').hasMatch(file.path)) {
        await processManager.runProcess(CliCommand('chmod 0755 ${file.path}'));
      }
    }
  }
}
