// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';

import 'commands/analyze.dart';
import 'commands/list.dart';
import 'commands/packages_get.dart';

class DevToolsCommandRunner extends CommandRunner {
  DevToolsCommandRunner()
      : super('devman', 'A repo management tool for DevTools.') {
    addCommand(PackagesGetCommand());
    addCommand(AnalyzeCommand());
    addCommand(ListCommand());
  }
}
