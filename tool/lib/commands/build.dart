// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/commands/shared.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

/// This command builds the DevTools Flutter web app.
///
/// By default, this command builds DevTools in release mode, but this can be
/// overridden by passing 'debug' or 'profile' as the
/// [BuildCommandArgs.buildMode] argument. For testing embedded content in
/// VS Code, 'profile' or the default 'release' mode must be used because
/// the '--dart2js-optimization=O1' flag that is passed for 'debug' builds
/// will cause issues with the VS Code embedding.
///
/// If the [BuildCommandArgs.useFlutterFromPath] argument is present, the
/// Flutter SDK will not be updated to the latest Flutter candidate before
/// building DevTools. Use this flag to save the cost of updating the Flutter
/// SDK when you already have the proper SDK checked out. This is helpful when
/// developing with the DevTools server.
///
/// If the [BuildCommandArgs.updatePerfetto] argument is present, the
/// precompiled bits for Perfetto will be updated from the
/// `devtools_tool update-perfetto` command as part of the DevTools build
/// process.
///
/// If [BuildCommandArgs.pubGet] argument is negated (e.g. --no-pub-get), then
/// `devtools_tool pub-get --only-main` command will not be run before building
/// the DevTools web app. Use this flag to save the cost of updating pub
/// packages if your pub cahce does not need to be updated. This is helpful when
/// developing with the DevTools server.
class BuildCommand extends Command {
  BuildCommand() {
    argParser
      ..addUpdateFlutterFlag()
      ..addUpdatePerfettoFlag()
      ..addPubGetFlag()
      ..addBulidModeOption()
      ..addWasmFlag();
  }

  @override
  String get name => 'build';

  @override
  String get description => 'Prepares a release build of DevTools.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();
    final results = argResults!;
    final updateFlutter =
        results[BuildCommandArgs.updateFlutter.flagName] as bool;
    final updatePerfetto =
        results[BuildCommandArgs.updatePerfetto.flagName] as bool;
    final runPubGet = results[BuildCommandArgs.pubGet.flagName] as bool;
    final buildMode = results[BuildCommandArgs.buildMode.flagName] as String;
    final useWasm = results[BuildCommandArgs.wasm.flagName] as bool;

    final webBuildDir =
        Directory(path.join(repo.devtoolsAppDirectoryPath, 'build', 'web'));

    if (updateFlutter) {
      logStatus('updating tool/flutter-sdk to the latest flutter candidate');
      await processManager.runProcess(CliCommand.tool(['update-flutter-sdk']));
    }

    if (updatePerfetto) {
      logStatus('updating the bundled Perfetto assets');
      await processManager.runProcess(CliCommand.tool(['update-perfetto']));
    }

    logStatus('cleaning project');
    if (webBuildDir.existsSync()) {
      webBuildDir.deleteSync(recursive: true);
    }
    await processManager.runProcess(
      CliCommand.flutter(['clean']),
      workingDirectory: repo.devtoolsAppDirectoryPath,
    );

    logStatus(
      'building DevTools in $buildMode mode${useWasm ? ' with dart2wasm' : ''}',
    );
    await processManager.runAll(
      commands: [
        if (runPubGet) CliCommand.tool(['pub-get', '--only-main']),
        CliCommand.flutter(
          [
            'build',
            'web',
            if (useWasm)
              '--wasm'
            else ...[
              '--web-renderer',
              'canvaskit',
              // Do not minify stack traces in debug mode.
              if (buildMode == 'debug') '--dart2js-optimization=O1',
              if (buildMode != 'debug') '--$buildMode',
            ],
            '--pwa-strategy=offline-first',
            '--no-tree-shake-icons',
          ],
        ),
      ],
      workingDirectory: repo.devtoolsAppDirectoryPath,
    );

    // TODO(kenz): investigate if we need to perform a windows equivalent of
    // `chmod` or if we even need to perform `chmod` for linux / mac anymore.
    if (!Platform.isWindows) {
      final canvaskitDir = Directory(path.join(webBuildDir.path, 'canvaskit'));
      for (final file in canvaskitDir.listSync()) {
        if (RegExp(r'canvaskit\..*').hasMatch(file.path)) {
          await processManager
              .runProcess(CliCommand('chmod', ['0755', file.path]));
        }
      }
    }
  }
}
