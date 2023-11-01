// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:devtools_tool/commands/fix_goldens.dart';
import 'package:devtools_tool/commands/generate_code.dart';
import 'package:devtools_tool/commands/sync.dart';
import 'package:devtools_tool/commands/update_flutter_sdk.dart';
import 'package:io/io.dart';

import 'commands/analyze.dart';
import 'commands/list.dart';
import 'commands/pub_get.dart';
import 'commands/release_helper.dart';
import 'commands/repo_check.dart';
import 'commands/rollback.dart';
import 'commands/update_dart_sdk_deps.dart';
import 'commands/update_version.dart';

class DevToolsCommandRunner extends CommandRunner {
  DevToolsCommandRunner()
      : super('devtools_tool', 'A repo management tool for DevTools.') {
    addCommand(AnalyzeCommand());
    addCommand(FixGoldensCommand());
    addCommand(GenerateCodeCommand());
    addCommand(ListCommand());
    addCommand(PubGetCommand());
    addCommand(ReleaseHelperCommand());
    addCommand(RepoCheckCommand());
    addCommand(RollbackCommand());
    addCommand(SyncCommand());
    addCommand(UpdateDartSdkDepsCommand());
    addCommand(UpdateDevToolsVersionCommand());
    addCommand(UpdateFlutterSdkCommand());
  }

  @override
  Future runCommand(ArgResults topLevelResults) async {
    try {
      return await super.runCommand(topLevelResults);
    } finally {
      // Closes stdin for the entire program.
      await sharedStdIn.terminate();
    }
  }
}
