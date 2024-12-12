// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as p;

import '../license_utils.dart';

const _argConfig = 'config';
const _argDirectory = 'directory';
const _dryRun = 'dry-run';

/// This command updates license headers for the configured files.
///
/// The config file is a YAML file as defined in [LicenseConfig].
///
/// If directory is not set, it will default to the current directory.
///
/// When the '--dry-run' flag is passed in, a list of files to update will
/// be logged, but no files will be modified.
///
/// To run this script
/// `dt update-licenses [--f <config-file>] [--d <directory>] [--dry-run]`
class UpdateLicensesCommand extends Command {
  UpdateLicensesCommand() {
    argParser
      ..addOption(
        _argConfig,
        abbr: 'c',
        defaultsTo: p.join(Directory.current.path, 'update_licenses.yaml'),
        help:
            'The path to the YAML license config file. Defaults to '
            'update_licenses.yaml',
      )
      ..addOption(
        _argDirectory,
        defaultsTo: Directory.current.path,
        abbr: 'd',
        help: 'Update license headers for files in the directory.',
      )
      ..addFlag(
        _dryRun,
        negatable: false,
        defaultsTo: false,
        help:
            'If set, log a list of files that require an update, but do not '
            'modify any files.',
      );
  }

  @override
  String get description => 'Update license headers as configured.';

  @override
  String get name => 'update-licenses';

  @override
  Future run() async {
    final config = LicenseConfig.fromYamlFile(
      File(argResults![_argConfig] as String),
    );
    final directory = Directory(argResults![_argDirectory] as String);
    final dryRun = argResults![_dryRun] as bool;
    final log = Logger.standard();
    final header = LicenseHeader();
    final results = await header.bulkUpdate(
      directory: directory,
      config: config,
      dryRun: dryRun,
    );
    final updatedPaths = results.updatedPaths;
    final prefix = dryRun ? 'Requires update: ' : 'Updated: ';
    log.stdout('$prefix ${updatedPaths.join(", ")}');
  }
}
