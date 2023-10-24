// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:io/io.dart';

import '../utils.dart';

class SyncCommand extends Command {
  @override
  String get name => 'sync';

  @override
  String get description =>
      'Syncs the DevTools repo to HEAD, upgrades dependencies, and performs code generation.';

  @override
  Future run() async {
    final processManager = ProcessManager();
    await processManager.runProcess(
      CliCommand.from('git', ['pull', 'upstream', 'master']),
    );
    await processManager.runProcess(
      CliCommand.tool('generate-code --upgrade'),
    );

    // Closes stdin for the entire program.
    await sharedStdIn.terminate();
  }
}
