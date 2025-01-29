// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
      CliCommand.git(['pull', 'upstream', 'master']),
    );
    await processManager.runProcess(CliCommand.tool(['update-flutter-sdk']));
    await processManager.runProcess(
      CliCommand.tool(['generate-code', '--upgrade']),
    );
  }
}
