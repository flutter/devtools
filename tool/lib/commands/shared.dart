// Copyright 2020 The Chromium Authors. All rights reserved.
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
      BuildCommandArgs.buildMode.name,
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

  void addUseLocalFlutterFlag() {
    addFlag(
      BuildCommandArgs.useLocalFlutter.flagName,
      negatable: false,
      defaultsTo: false,
      help: 'Whether to use the Flutter SDK on PATH instead of the Flutter SDK '
          'contained in the "tool/flutter-sdk" directory.',
    );
  }
}

enum BuildCommandArgs {
  buildMode('build-mode'),
  pubGet('pub-get'),
  useLocalFlutter('use-local-flutter'),
  updatePerfetto('update-perfetto');

  const BuildCommandArgs(this.flagName);

  final String flagName;

  String asArg({bool negated = false}) =>
      valueAsArg(flagName, negated: negated);
}

String valueAsArg(String value, {bool negated = false}) =>
    '--${negated ? 'no-' : ''}$value';
