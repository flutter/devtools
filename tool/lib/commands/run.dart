// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:devtools_tool/commands/shared.dart';
import 'package:io/io.dart';

import '../utils.dart';

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
