// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';

import 'commands/analyze.dart';
import 'commands/list.dart';
import 'commands/packages_get.dart';
import 'commands/repo_check.dart';
import 'commands/rollback.dart';
import 'commands/update_dart_sdk_deps.dart';

class DevToolsCommandRunner extends CommandRunner {
  DevToolsCommandRunner()
      : super('devtools_tool', 'A repo management tool for DevTools.') {
    addCommand(AnalyzeCommand());
    addCommand(RepoCheckCommand());
    addCommand(ListCommand());
    addCommand(PackagesGetCommand());
    addCommand(RollbackCommand());
    addCommand(UpdateDartSdkDepsCommand());
  }
}
