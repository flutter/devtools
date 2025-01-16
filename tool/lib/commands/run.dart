// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:args/command_runner.dart';
import 'package:devtools_tool/commands/shared.dart';
import 'package:io/io.dart';

import '../utils.dart';

/// Runs the DevTools web app in debug mode with `flutter run` and connects it
/// to a locally running instance of the DevTools server.
///
/// To open a debug connection to the DevTools server, pass the `--debug-server`
/// flag to this command.
class RunCommand extends Command {
  RunCommand() {
    argParser.addDebugServerFlag();
  }

  @override
  String get name => 'run';

  @override
  String get description =>
      'Runs the DevTools web app in debug mode using "flutter run" and connects'
      ' it to a locally running instance of the DevTools server.';

  @override
  Future run() async {
    final processManager = ProcessManager();
    final process = await processManager.runProcess(
      CliCommand.tool([
        'serve',
        SharedCommandArgs.runApp.asArg(),
        ...argResults!.arguments,
      ]),
    );
    if (process.exitCode == 1) {
      throw Exception('Something went wrong while running `dt run`.');
    }
  }
}
