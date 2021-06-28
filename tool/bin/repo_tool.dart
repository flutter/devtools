// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.10

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_repo/repo_tool.dart';

void main(List<String> args) async {
  final runner = DevToolsCommandRunner();
  try {
    final dynamic result = await runner.run(args);
    exit(result is int ? result : 0);
  } catch (e) {
    if (e is UsageException) {
      stderr.writeln('$e');
      // Return an exit code representing a usage error.
      exit(64);
    } else {
      stderr.writeln('$e');
      // Return a general failure exit code.
      exit(1);
    }
  }
}
