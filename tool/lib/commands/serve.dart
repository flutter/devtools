// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/model.dart';
import 'package:devtools_tool/utils.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import 'shared.dart';

const _buildAppFlag = 'build-app';

// TODO(https://github.com/flutter/devtools/issues/7232): Consider using
// AllowAnythingParser instead of manually passing these args through.
const _machineFlag = 'machine';
const _dtdUriFlag = 'dtd-uri';
const _allowEmbeddingFlag = 'allow-embedding';
const _serveWithDartSdkFlag = 'serve-with-dart-sdk';

/// This command builds DevTools in release mode by running the
/// `dt build` command and then serves DevTools with a locally
/// running DevTools server.
///
/// If the [_buildAppFlag] argument is negated (e.g. --no-build-app), then the
/// DevTools web app will not be rebuilt before serving. The following arguments
/// are ignored if '--no-build-app' is present in the list of arguments passed
/// to this command. All of the following commands are passed along to the
/// `dt build` command.
///
/// If the [SharedCommandArgs.runApp] argument is passed (e.g. --run-app), then
/// DevTools will be run with `flutter run` instead of being built with
/// `flutter build web`. The DevTools web app running from Flutter Tool will be
/// connected to a locally running instance of the DevTools server.
///
/// If the [SharedCommandArgs.debugServer] argument is present, the DevTools
/// server will be started with the `--observe` flag. This will allow you to
/// debug and profile the server with a local VM service connection. By default,
/// this will set `--pause-isolates-on-start` and
/// `--pause-isolates-on-unhandled-exceptions` for the DevTools server VM
/// service connection.
///
/// If the [SharedCommandArgs.useFlutterFromPath] argument is present, the
/// Flutter SDK will not be updated to the latest Flutter candidate before
/// building DevTools. Use this flag to save the cost of updating the Flutter
/// SDK when you already have the proper SDK checked out. This is helpful when
/// developing with the DevTools server.
///
/// If the [SharedCommandArgs.updatePerfetto] argument is present, the
/// precompiled bits for Perfetto will be updated from the
/// `dt update-perfetto` command as part of the DevTools build
/// process.
///
/// If [SharedCommandArgs.pubGet] argument is negated (e.g. --no-pub-get), then
/// `dt pub-get --only-main` command will not be run before building
/// the DevTools web app. Use this flag to save the cost of updating pub
/// packages if your pub cahce does not need to be updated. This is helpful when
/// developing with the DevTools server.
///
/// The [SharedCommandArgs.buildMode] argument specifies the Flutter build mode
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
            ' server. If --no-build-app is passed, the existing assets from'
            ' devtools_app/build/web will be used.',
      )
      ..addFlag(
        SharedCommandArgs.runApp.flagName,
        negatable: false,
        defaultsTo: false,
        help:
            'Whether to run the DevTools web app using `flutter run` instead'
            ' of building it using `flutter build web` and serving the assets'
            ' directly from the DevTools server.',
      )
      ..addDebugServerFlag()
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

  static const _devToolsServerAddressLine = 'Serving DevTools at ';
  static const _debugServerVmServiceLine =
      'The Dart VM service is listening on ';
  static const _debugServerDartDevToolsLine =
      'The Dart DevTools debugger and profiler is available at: ';
  static const _runAppVmServiceLine =
      'A Dart VM Service on Chrome is available at: ';
  static const _runAppFlutterDevToolsLine =
      'The Flutter DevTools debugger and profiler on Chrome is available at: ';

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
    final runApp = results[SharedCommandArgs.runApp.flagName] as bool;
    final debugServer = results[SharedCommandArgs.debugServer.flagName] as bool;
    final updateFlutter =
        results[SharedCommandArgs.updateFlutter.flagName] as bool;
    final updatePerfetto =
        results[SharedCommandArgs.updatePerfetto.flagName] as bool;
    final useWasm = results[SharedCommandArgs.wasm.flagName] as bool;
    final noStripWasm = results[SharedCommandArgs.noStripWasm.flagName] as bool;
    final runPubGet = results[SharedCommandArgs.pubGet.flagName] as bool;
    final devToolsAppBuildMode =
        results[SharedCommandArgs.buildMode.flagName] as String;
    final serveWithDartSdk = results[_serveWithDartSdkFlag] as String?;
    final forMachine = results[_machineFlag] as bool;

    // TODO(https://github.com/flutter/devtools/issues/8643): Support running in
    // machine mode with a debuggable DevTools app.
    if (runApp && forMachine) {
      throw Exception(
        'Machine mode is not supported with `flutter run` DevTools.\n'
        'Please use either --machine or --run-app, not both.\n'
        'See https://github.com/flutter/devtools/issues/8643 for details.',
      );
    }

    // Any flag that we aren't removing here is intended to be passed through.
    final remainingArguments =
        List.of(results.arguments)
          ..remove(SharedCommandArgs.updateFlutter.asArg())
          ..remove(SharedCommandArgs.updateFlutter.asArg(negated: true))
          ..remove(SharedCommandArgs.updatePerfetto.asArg())
          ..remove(SharedCommandArgs.wasm.asArg())
          ..remove(SharedCommandArgs.noStripWasm.asArg())
          ..remove(valueAsArg(_buildAppFlag))
          ..remove(valueAsArg(_buildAppFlag, negated: true))
          ..remove(SharedCommandArgs.runApp.asArg())
          ..remove(SharedCommandArgs.debugServer.asArg())
          ..remove(SharedCommandArgs.pubGet.asArg())
          ..remove(SharedCommandArgs.pubGet.asArg(negated: true))
          ..removeWhere(
            (element) =>
                element.startsWith(SharedCommandArgs.buildMode.asArg()),
          )
          ..removeWhere(
            (element) => element.startsWith(valueAsArg(_serveWithDartSdkFlag)),
          );

    final localDartSdkLocation = Platform.environment['LOCAL_DART_SDK'];
    if (localDartSdkLocation == null) {
      throw Exception(
        'LOCAL_DART_SDK environment variable not set. Please add '
        'the following to your \'.bash_profile\' or \'.bashrc\' file:\n'
        'export LOCAL_DART_SDK=<absolute/path/to/my/sdk>',
      );
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

    final devToolsBuildLocation = path.join(
      repo.devtoolsAppDirectoryPath,
      'build',
      'web',
    );

    if (buildApp && !runApp) {
      final process = await processManager.runProcess(
        CliCommand.tool([
          'build',
          SharedCommandArgs.updateFlutter.asArg(negated: !updateFlutter),
          if (updatePerfetto) SharedCommandArgs.updatePerfetto.asArg(),
          if (useWasm) SharedCommandArgs.wasm.asArg(),
          if (noStripWasm) SharedCommandArgs.noStripWasm.asArg(),
          '${SharedCommandArgs.buildMode.asArg()}=$devToolsAppBuildMode',
          SharedCommandArgs.pubGet.asArg(negated: !runPubGet),
        ]),
      );
      if (process.exitCode == 1) {
        throw Exception('Something went wrong while running `dt build`');
      }
      logStatus('completed building DevTools: $devToolsBuildLocation');
    }

    logStatus('running pub get for DDS in the local dart sdk');
    await processManager.runProcess(
      CliCommand.dart(['pub', 'get']),
      workingDirectory: path.join(localDartSdkLocation, 'pkg', 'dds'),
    );

    logStatus('serving DevTools with a local devtools server...');
    final ddsServeLocalScriptPath = path.join(
      'pkg',
      'dds',
      'tool',
      'devtools_server',
      'serve_local.dart',
    );

    // The address of the locally running DevTools server.
    String? devToolsServerAddress;

    // This is the DevTools URI associated with the DevTools server process
    // when the '--debug-server' flag is present. This DevTools connection
    // allows you to debug the DevTools server logic.
    String? debugServerDevToolsConnection;

    // This is the VM Service URI associated with the DevTools server process
    // when the '--debug-server' flag is present.
    String? debugServerVmServiceUri;

    void processServeLocalOutput(String line) {
      if (line.startsWith(_debugServerVmServiceLine)) {
        debugServerVmServiceUri =
            line.substring(_debugServerVmServiceLine.length).trim();
      } else if (line.startsWith(_debugServerDartDevToolsLine)) {
        debugServerDevToolsConnection =
            line.substring(_debugServerDartDevToolsLine.length).trim();
      } else if (line.startsWith(_devToolsServerAddressLine)) {
        // This will pull the server address from a String like:
        // "Serving DevTools at http://127.0.0.1:9104.".
        final regexp = RegExp(
          r'http:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+',
        );
        final match = regexp.firstMatch(line);
        if (match != null) {
          devToolsServerAddress = match.group(0);
        }
      }
    }

    // This call will not exit until explicitly terminated by the user.
    final cliCommand = CliCommand.dart([
      if (debugServer) ...['run', '--observe=0'],
      ddsServeLocalScriptPath,
      if (runApp)
        // When running DevTools via `flutter run`, the [flutterRunProcess]
        // below will launch DevTools in the browser.
        '--no-launch-browser'
      else
        // Only pass a build location if the server is serving the web assets
        // (i.e. not when DevTools app is ran via `flutter run`).
        '--devtools-build=$devToolsBuildLocation',
      // Pass any args that were provided to our script along. This allows IDEs
      // to pass `--machine` (etc.) so that this script can behave the same as
      // the "dart devtools" command for testing local DevTools/server changes.
      ...remainingArguments,
    ], sdkOverride: serveWithDartSdk);
    if (forMachine) {
      // If --machine flag is true, then the output is a tool-readable JSON.
      // Therefore, skip reading the process output and instead just run the
      // process.
      return processManager.runProcess(
        cliCommand,
        workingDirectory: localDartSdkLocation,
      );
    }

    final serveLocalProcess = await startIndependentProcess(
      cliCommand,
      workingDirectory: localDartSdkLocation,
      waitForOutput: _devToolsServerAddressLine,
      onOutput: processServeLocalOutput,
    );

    Process? flutterRunProcess;
    if (runApp) {
      if (devToolsServerAddress == null) {
        await _killProcess(serveLocalProcess);
        throw Exception(
          'Cannot run DevTools and connect to the DevTools server because '
          'devToolsServerAddress is null.',
        );
      }

      // This is the DevTools URI associated with the DevTools web app when it is
      // run using `flutter run` (e.g. when [runApp] is true).
      String? devToolsWebAppDevToolsConnection;

      // This is the VM service URI associated with the DevTools web app when it
      // is run using `flutter run` (e.g. when [runApp] is true).
      String? devToolsWebAppVmServiceUri;

      void processFlutterRunOutput(String line) {
        if (line.contains(_runAppVmServiceLine)) {
          final index = line.indexOf(_runAppVmServiceLine);
          devToolsWebAppVmServiceUri =
              line.substring(index + _runAppVmServiceLine.length).trim();
        } else if (line.contains(_runAppFlutterDevToolsLine)) {
          final index = line.indexOf(_runAppFlutterDevToolsLine);
          devToolsWebAppDevToolsConnection =
              line.substring(index + _runAppFlutterDevToolsLine.length).trim();
        }
      }

      logStatus('running DevTools');
      flutterRunProcess = await startIndependentProcess(
        CliCommand.flutter([
          'run',
          '-d',
          'chrome',
          // TODO(https://github.com/flutter/flutter/issues/160130):
          //  [flutterRunProcess] exits without the --verbose flag.
          '--verbose',
          // Add the trailing slash because this is what DevTools app expects.
          '--dart-define=debug_devtools_server=$devToolsServerAddress/',
        ]),
        workingDirectory: repo.devtoolsAppDirectoryPath,
        waitForOutput: _runAppFlutterDevToolsLine,
        onOutput: processFlutterRunOutput,
      );

      // Consolidate important stdout content for easy access.
      final debugServerContent =
          debugServer
              ? '''
- VM Service URI: $debugServerVmServiceUri
- DevTools URI for debugging the DevTools server: $debugServerDevToolsConnection
'''
              : '';

      print('''
-------------------------------------------------------------------

The DevTools web app should have just launched on Chrome.
- VM Service URI: $devToolsWebAppVmServiceUri
- DevTools URI for debugging the DevTools web app: $devToolsWebAppDevToolsConnection

The DevTools server is running at: $devToolsServerAddress.
$debugServerContent
-------------------------------------------------------------------
''');
    }

    await _waitForAndHandleExit(
      serveLocalProcess: serveLocalProcess,
      flutterRunProcess: flutterRunProcess,
    );
  }

  Future<void> _waitForAndHandleExit({
    required Process serveLocalProcess,
    required Process? flutterRunProcess,
  }) async {
    final serveLocalProcessExited = Completer<int>();
    final flutterRunProcessExited = Completer<int>();
    unawaited(
      serveLocalProcess.exitCode.then((code) {
        serveLocalProcessExited.complete(code);
      }),
    );
    if (flutterRunProcess != null) {
      unawaited(
        flutterRunProcess.exitCode.then((code) {
          flutterRunProcessExited.complete(code);
        }),
      );
    }

    await Future.any([
      serveLocalProcessExited.future,
      flutterRunProcessExited.future,
    ]);

    if (serveLocalProcessExited.isCompleted &&
        !flutterRunProcessExited.isCompleted &&
        flutterRunProcess != null) {
      final exitCode = await serveLocalProcessExited.future;
      logStatus(
        'Killing the flutterRunProcess because the serveLocalProcess has '
        'exited with code $exitCode.',
      );
      await _killProcess(flutterRunProcess);
    }

    if (flutterRunProcessExited.isCompleted &&
        !serveLocalProcessExited.isCompleted) {
      final exitCode = await flutterRunProcessExited.future;
      logStatus(
        'Killing the serveLocalProcess because the flutterRunProcess has '
        'exited with code $exitCode.',
      );
      await _killProcess(serveLocalProcess);
    }
  }

  Future<void> _killProcess(Process? process) async {
    if (process != null) {
      Process.killPid(process.pid, ProcessSignal.sigint);
      await process.exitCode;
    }
  }
}
