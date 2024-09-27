// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../model.dart';

class ListCommand extends Command {
  @override
  String get name => 'list';

  @override
  String get description => 'List all the DevTools packages.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance();
    print('DevTools repo at ${repo.repoPath}.');

    final packages = repo.getPackages();

    print('\n${packages.length} packages:');

    for (final p in packages) {
      print('  ${p.relativePath}${path.separator}');
    }
  }
}
