// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/model.dart';
import 'package:devtools_tool/utils.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import 'shared.dart';

const _buildAppFlag = 'build-app';
const _debugServerFlag = 'debug-server';

// TODO(https://github.com/flutter/devtools/issues/7232): Consider using
// AllowAnythingParser instead of manually passing these args through.
const _machineFlag = 'machine';
const _dtdUriFlag = 'dtd-uri';
const _allowEmbeddingFlag = 'allow-embedding';
const _serveWithDartSdkFlag = 'serve-with-dart-sdk';

/// This command builds DevTools in release mode by running the
/// `devtools_tool build` command and then serves DevTools with a locally
/// running DevTools server.
///
/// If the [_buildAppFlag] argument is negated (e.g. --no-build-app), then the
/// DevTools web app will not be rebuilt before serving. The following arguments
/// are ignored if '--no-build-app' is present in the list of arguments passed
/// to this command. All of the following commands are passed along to the
/// `devtools_tool build` command.
///
/// If the [_debugServerFlag] argument is present, the DevTools server will be
/// started with the `--observe` flag. This will allow you to debug and profile
/// the server with a local VM service connection. By default, this will set
/// `--pause-isolates-on-start` and `--pause-isolates-on-unhandled-exceptions`
/// for the DevTools server VM service connection.
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
///
/// The [BuildCommandArgs.buildMode] argument specifies the Flutter build mode
/// that the DevTools web app will be built in ('release', 'profile', 'debug').
/// This defaults to 'release' if unspecified.
class ServeCommand extends Command {
  ServeCommand() {
    argParser
      ..addFlag(
        _buildAppFlag,
        negatable: true,
        defaultsTo: true,
        help:
            'Whether to build the DevTools web app before starting the DevTools'
            ' server.',
      )
      ..addFlag(
        _debugServerFlag,
        negatable: false,
        defaultsTo: false,
        help: 'Enable debugging for the DevTools server.',
      )
      ..addUpdateFlutterFlag()
      ..addUpdatePerfettoFlag()
      ..addPubGetFlag()
      ..addBulidModeOption()
      ..addWasmFlag()
      ..addNoStripWasmFlag()
      // Flags defined in the server in DDS.
      ..addFlag(
        _machineFlag,
        negatable: false,
        help: 'Sets output format to JSON for consumption in tools.',
      )
      ..addOption(
        _dtdUriFlag,
        help: 'Sets the dtd uri when starting the devtools server',
      )
      ..addFlag(
        _allowEmbeddingFlag,
        help: 'Allow embedding DevTools inside an iframe.',
      )
      ..addOption(
        _serveWithDartSdkFlag,
        help: 'Uses the specified Dart SDK to serve the DevTools server',
        valueHelp:
            '/Users/me/absolute_path_to/sdk/xcodebuild/ReleaseX64/dart-sdk/bin/dart',
      );
  }

  @override
  String get name => 'serve';

  @override
  String get description =>
      'Builds DevTools in release mode and serves the web app with a locally '
      'running DevTools server.';

  @override
  Future run() async {
    logStatus(
      'WARNING: if you have local changes in packages/devtools_shared, you will'
      ' need to add a path dependency override in sdk/pkg/dds/pubspec.yaml in'
      ' order for these changes to be picked up.',
    );

    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();

    final results = argResults!;
    final buildApp = results[_buildAppFlag] as bool;
    final debugServer = results[_debugServerFlag] as bool;
    final updateFlutter =
        results[BuildCommandArgs.updateFlutter.flagName] as bool;
    final updatePerfetto =
        results[BuildCommandArgs.updatePerfetto.flagName] as bool;
    final useWasm = results[BuildCommandArgs.wasm.flagName] as bool;
    final noStripWasm = results[BuildCommandArgs.noStripWasm.flagName] as bool;
    final runPubGet = results[BuildCommandArgs.pubGet.flagName] as bool;
    final devToolsAppBuildMode =
        results[BuildCommandArgs.buildMode.flagName] as String;
    final serveWithDartSdk = results[_serveWithDartSdkFlag] as String?;

    // Any flag that we aren't removing here is intended to be passed through.
    final remainingArguments = List.of(results.arguments)
      ..remove(BuildCommandArgs.updateFlutter.asArg())
      ..remove(BuildCommandArgs.updateFlutter.asArg(negated: true))
      ..remove(BuildCommandArgs.updatePerfetto.asArg())
      ..remove(BuildCommandArgs.wasm.asArg())
      ..remove(BuildCommandArgs.noStripWasm.asArg())
      ..remove(valueAsArg(_buildAppFlag))
      ..remove(valueAsArg(_buildAppFlag, negated: true))
      ..remove(valueAsArg(_debugServerFlag))
      ..remove(BuildCommandArgs.pubGet.asArg())
      ..remove(BuildCommandArgs.pubGet.asArg(negated: true))
      ..removeWhere(
        (element) => element.startsWith(BuildCommandArgs.buildMode.asArg()),
      )
      ..removeWhere(
        (element) => element.startsWith(valueAsArg(_serveWithDartSdkFlag)),
      );

    final localDartSdkLocation = Platform.environment['LOCAL_DART_SDK'];
    if (localDartSdkLocation == null) {
      throw Exception('LOCAL_DART_SDK environment variable not set. Please add '
          'the following to your \'.bash_profile\' or \'.bashrc\' file:\n'
          'export LOCAL_DART_SDK=<absolute/path/to/my/sdk>');
    }

    // Validate the path looks correct in case it was set without the /sdk or
    // similar.
    final pkgDir = Directory(path.join(localDartSdkLocation, 'pkg'));
    if (!pkgDir.existsSync()) {
      throw Exception(
        'No pkg directory found in LOCAL_DART_SDK at "${pkgDir.path}"\n'
        'Is LOCAL_DART_SDK set correctly to the "sdk" directory?',
      );
    }

    final devToolsBuildLocation =
        path.join(repo.devtoolsAppDirectoryPath, 'build', 'web');

    if (buildApp) {
      final process = await processManager.runProcess(
        CliCommand.tool([
          'build',
          BuildCommandArgs.updateFlutter.asArg(negated: !updateFlutter),
          if (updatePerfetto) BuildCommandArgs.updatePerfetto.asArg(),
          if (useWasm) BuildCommandArgs.wasm.asArg(),
          if (noStripWasm) BuildCommandArgs.noStripWasm.asArg(),
          '${BuildCommandArgs.buildMode.asArg()}=$devToolsAppBuildMode',
          BuildCommandArgs.pubGet.asArg(negated: !runPubGet),
        ]),
      );
      if (process.exitCode == 1) {
        throw Exception(
          'Something went wrong while running `devtools_tool build`',
        );
      }
      logStatus('completed building DevTools: $devToolsBuildLocation');
    }

    logStatus('running pub get for DDS in the local dart sdk');
    await processManager.runProcess(
      CliCommand.dart(['pub', 'get']),
      workingDirectory: path.join(localDartSdkLocation, 'pkg', 'dds'),
    );

    logStatus('serving DevTools with a local devtools server...');
    final serveLocalScriptPath = path.join(
      'pkg',
      'dds',
      'tool',
      'devtools_server',
      'serve_local.dart',
    );

    // This call will not exit until explicitly terminated by the user.
    await processManager.runProcess(
      CliCommand.dart(
        [
          if (debugServer) ...[
            'run',
            '--observe=0',
          ],
          serveLocalScriptPath,
          '--devtools-build=$devToolsBuildLocation',
          // Pass any args that were provided to our script along. This allows IDEs
          // to pass `--machine` (etc.) so that this script can behave the same as
          // the "dart devtools" command for testing local DevTools/server changes.
          ...remainingArguments,
        ],
        sdkOverride: serveWithDartSdk,
      ),
      workingDirectory: localDartSdkLocation,
    );
  }
}
