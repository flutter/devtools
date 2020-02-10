// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:tool/commands/rollback.dart';

import 'commands/analyze.dart';
import 'commands/list.dart';
import 'commands/packages_get.dart';
import 'commands/repo_check.dart';

class DevToolsCommandRunner extends CommandRunner {
  DevToolsCommandRunner()
      : super('repo_tool', 'A repo management tool for DevTools.') {
    addCommand(AnalyzeCommand());
    addCommand(RepoCheckCommand());
    addCommand(ListCommand());
    addCommand(PackagesGetCommand());
    addCommand(RollbackCommand());
  }
}
