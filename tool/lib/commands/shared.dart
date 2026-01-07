// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

extension CommandExtension on Command {
  void logStatus(String log) {
    print('[$name] $log');
  }
}

extension BuildCommandArgsExtension on ArgParser {
  void addBulidModeOption() {
    addOption(
      SharedCommandArgs.buildMode.flagName,
      allowed: ['debug', 'profile', 'release'],
      defaultsTo: 'release',
      help: 'The build mode to use for the DevTools web app.',
    );
  }

  void addPubGetFlag() {
    addFlag(
      SharedCommandArgs.pubGet.flagName,
      negatable: true,
      defaultsTo: true,
      help:
          'Whether to run `dt pub-get --only-main` before building'
          ' the DevTools web app.',
    );
  }

  void addUpdatePerfettoFlag() {
    addFlag(
      SharedCommandArgs.updatePerfetto.flagName,
      negatable: false,
      defaultsTo: false,
      help: 'Whether to update the Perfetto assets before building DevTools.',
    );
  }

  void addUpdateFlutterFlag() {
    addFlag(
      SharedCommandArgs.updateFlutter.flagName,
      negatable: true,
      defaultsTo: true,
      help:
          'Whether to update the Flutter SDK contained in the '
          '"tool/flutter-sdk" directory.',
    );
  }

  void addUpdateOnPathFlag() {
    addFlag(
      SharedCommandArgs.updateOnPath.flagName,
      negatable: false,
      help:
          'Update the Flutter SDK that is on PATH (your local '
          'flutter/flutter git checkout). This flag is to be used in '
          'combination with the ${SharedCommandArgs.updateFlutter.asArg()} '
          'flag.',
    );
  }

  void addWasmFlag() {
    addFlag(
      SharedCommandArgs.wasm.flagName,
      defaultsTo: true,
      negatable: true,
      help: 'Whether to build DevTools with dart2wasm instead of dart2js.',
    );
  }

  void addNoStripWasmFlag() {
    addFlag(
      SharedCommandArgs.noStripWasm.flagName,
      defaultsTo: false,
      help:
          'When this flag is present, static symbol names will be included in '
          'the resulting wasm file. This flag is ignored if the --wasm flag is '
          'not present.',
    );
  }

  void addNoMinifyWasmFlag() {
    addFlag(
      SharedCommandArgs.noMinifyWasm.flagName,
      defaultsTo: false,
      help:
          'When this flag is present, class names and errors will not be '
          'truncated. This flag is ignored if the --wasm flag is '
          'not present.',
    );
  }

  void addDebugServerFlag() {
    addFlag(
      SharedCommandArgs.debugServer.flagName,
      negatable: false,
      defaultsTo: false,
      help: 'Enable debugging for the DevTools server.',
    );
  }

  void addDartSdkOverrideOption() {
    addOption(
      SharedCommandArgs.dartSdkOverride.flagName,
      help: 'Uses the specified Dart SDK to serve the DevTools server',
      valueHelp:
          '/Users/me/absolute_path_to/sdk/xcodebuild/ReleaseX64/dart-sdk/bin/dart',
    );
  }
}

enum SharedCommandArgs {
  buildMode('build-mode'),
  debugServer('debug-server'),
  pubGet('pub-get'),
  wasm('wasm'),
  noStripWasm('no-strip-wasm'),
  noMinifyWasm('no-minify-wasm'),
  runApp('run-app'),
  dartSdkOverride('dart-sdk-override'),
  updateFlutter('update-flutter'),
  updateOnPath('update-on-path'),
  updatePerfetto('update-perfetto');

  const SharedCommandArgs(this.flagName);

  final String flagName;

  String asArg({bool negated = false}) =>
      valueAsArg(flagName, negated: negated);
}

String valueAsArg(String value, {bool negated = false}) =>
    '--${negated ? 'no-' : ''}$value';
