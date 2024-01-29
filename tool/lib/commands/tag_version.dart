// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import '../utils.dart';

class TagVersionCommand extends Command {
  @override
  String get name => 'tag-version';

  @override
  String get description =>
      'Creates a git tag for the current version of DevTools and pushes it to '
      'the DevTools Github repository.';

  @override
  Future run() async {
    final log = Logger.standard();

    final repo = DevToolsRepo.getInstance();
    final devtoolsAppPubspecPath =
        path.join(repo.devtoolsAppDirectoryPath, 'pubspec.yaml');
    final devtoolsAppPubspec = File(devtoolsAppPubspecPath);
    if (!devtoolsAppPubspec.existsSync()) {
      throw FileSystemException(
        'Could not find pubspec.yaml file at: $devtoolsAppPubspecPath',
      );
    }

    final yamlMap = loadYaml(devtoolsAppPubspec.readAsStringSync()) as YamlMap;
    final version = yamlMap['version'].toString();
    log.stdout('Current DevTools version: $version');

    final processManager = ProcessManager();

    final gitTag = 'v$version';
    log.stdout('Creating git tag: $gitTag');
    await processManager.runAll(
      commands: [
        CliCommand.git(['tag', '-a', gitTag, '-m', 'DevTools $version']),
        CliCommand.git(['push', 'upstream', gitTag]),
      ],
    );
  }
}
