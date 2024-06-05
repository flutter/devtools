// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
      BuildCommandArgs.buildMode.flagName,
      allowed: ['debug', 'profile', 'release'],
      defaultsTo: 'release',
      help: 'The build mode to use for the DevTools web app. This should only'
          ' be "debug" or "profile" for the purpose of local development.',
    );
  }

  void addPubGetFlag() {
    addFlag(
      BuildCommandArgs.pubGet.flagName,
      negatable: true,
      defaultsTo: true,
      help: 'Whether to run `devtools_tool pub-get --only-main` before building'
          ' the DevTools web app.',
    );
  }

  void addUpdatePerfettoFlag() {
    addFlag(
      BuildCommandArgs.updatePerfetto.flagName,
      negatable: false,
      defaultsTo: false,
      help: 'Whether to update the Perfetto assets before building DevTools.',
    );
  }

  void addUpdateFlutterFlag() {
    addFlag(
      BuildCommandArgs.updateFlutter.flagName,
      negatable: true,
      defaultsTo: true,
      help: 'Whether to update the Flutter SDK contained in the '
          '"tool/flutter-sdk" directory.',
    );
  }

  void addWasmFlag() {
    addFlag(
      BuildCommandArgs.wasm.flagName,
      defaultsTo: false,
      help: 'Whether to build DevTools with dart2wasm instead of dart2js.',
    );
  }

  void addNoStripWasmFlag() {
    addFlag(
      BuildCommandArgs.noStripWasm.flagName,
      defaultsTo: false,
      help:
          'When this flag is present, static symbol names will be included in '
          'the resulting wasm file. This flag is ignored if the --wasm flag is '
          'not present.',
    );
  }
}

enum BuildCommandArgs {
  buildMode('build-mode'),
  pubGet('pub-get'),
  wasm('wasm'),
  noStripWasm('no-strip-wasm'),
  updateFlutter('update-flutter'),
  updatePerfetto('update-perfetto');

  const BuildCommandArgs(this.flagName);

  final String flagName;

  String asArg({bool negated = false}) =>
      valueAsArg(flagName, negated: negated);
}

String valueAsArg(String value, {bool negated = false}) =>
    '--${negated ? 'no-' : ''}$value';
