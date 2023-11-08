// Copyright 2022 The Chromium Authors. All rights reserved.
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
const _buildAppFlag = 'build-app';
const _machineFlag = 'machine';
const _allowEmbeddingFlag = 'allow-embedding';

/// This command builds DevTools in release mode by running the
/// `devtools_tool build-release` command and then serves DevTools with a
/// locally running DevTools server.
///
/// If the [_buildAppFlag] is negated (e.g. --no-build-app), then the DevTools
/// web app will not be rebuilt before serving.
///
/// If [_useLocalFlutterFlag] is present, the Flutter SDK will not be updated to
/// the latest Flutter candidate. Use this flag to save the cost of updating the
/// Flutter SDK when you already have the proper SDK checked out.
///
/// If [_updatePerfettoFlag] is present, the precompiled bits for Perfetto will
/// be updated from the `devtools_tool update-perfetto` command as part of the
/// DevTools build process (e.g. running `devtools_tool build-release`).
class ServeCommand extends Command {
  ServeCommand() {
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
      )
      ..addFlag(
        _buildAppFlag,
        negatable: true,
        defaultsTo: true,
        help:
            'Whether to build the DevTools app in release mode before starting '
            'the DevTools server.',
      )
      // Flags defined in the server in DDS.
      ..addFlag(
        _machineFlag,
        negatable: false,
        help: 'Sets output format to JSON for consumption in tools.',
      )
      ..addFlag(
        _allowEmbeddingFlag,
        help: 'Allow embedding DevTools inside an iframe.',
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
    final repo = DevToolsRepo.getInstance();
    final processManager = ProcessManager();

    final useLocalFlutter = argResults![_useLocalFlutterFlag];
    final updatePerfetto = argResults![_updatePerfettoFlag];
    final buildApp = argResults![_buildAppFlag];

    final remainingArguments = List.of(argResults!.arguments)
      ..remove(_useLocalFlutterFlag)
      ..remove(_updatePerfettoFlag)
      ..remove(_buildAppFlag)
      ..remove('--no-$_buildAppFlag');

    final localDartSdkLocation = Platform.environment['LOCAL_DART_SDK'];
    if (localDartSdkLocation == null) {
      throw Exception('LOCAL_DART_SDK environment variable not set. Please add '
          'the following to your \'.bash_profile\' or \'.bashrc\' file:\n'
          'export LOCAL_DART_SDK=<absolute/path/to/my/dart-sdk/sdk>');
    }

    // Validate the path looks correct in case it was set without the /sdk or
    // similar.
    final pkgDir = Directory(path.join(localDartSdkLocation, 'pkg'));
    if (!pkgDir.existsSync()) {
      throw Exception(
        'No pkg directory found in LOCAL_DART_SDK at "${pkgDir.path}"\n'
        'Is LOCAL_DART_SDK set correctly to the dart-sdk${path.separator}sdk '
        'directory?',
      );
    }

    final devToolsBuildLocation =
        path.join(repo.devtoolsAppDirectoryPath, 'build', 'web');
    if (buildApp) {
      final process = await processManager.runProcess(
        CliCommand.tool(
          'build-release'
          ' ${useLocalFlutter ? '--$_useLocalFlutterFlag' : ''}'
          ' ${updatePerfetto ? '--$_updatePerfettoFlag' : ''}',
        ),
      );
      if (process.exitCode == 1) {
        throw Exception(
          'Something went wrong while running `devtools_tool build-release`',
        );
      }
      logStatus('completed building DevTools: $devToolsBuildLocation');
    }

    logStatus('running pub get for DDS in the local dart sdk');
    await processManager.runProcess(
      CliCommand.from('dart', ['pub', 'get']),
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
      CliCommand.from(
        'dart',
        [
          serveLocalScriptPath,
          '--devtools-build=$devToolsBuildLocation',
          // Pass any args that were provided to our script along. This allows IDEs
          // to pass `--machine` (etc.) so that this script can behave the same as
          // the "dart devtools" command for testing local DevTools/server changes.
          ...remainingArguments,
        ],
      ),
      workingDirectory: localDartSdkLocation,
    );
  }
}
