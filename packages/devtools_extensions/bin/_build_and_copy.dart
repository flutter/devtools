// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

/// Command that builds a DevTools extension and copies the built output to
/// the parent package extension location.
///
/// Example usage:
///
/// dart pub global activate devtools_extensions;
/// dart run devtools_extensions build_and_copy \
///  --source=path/to/your_extension_web_app \
///  --dest=path/to/your_pub_package/extension/devtools
class BuildExtensionCommand extends Command {
  BuildExtensionCommand() {
    argParser
      ..addOption(
        'source',
        help: 'The source location for the extension flutter web app (can  be '
            'relative or absolute)',
        valueHelp: 'path/to/foo/packages/foo_devtools_extension',
        mandatory: true,
      )
      ..addOption(
        'dest',
        help: 'The destination location for the extension build output (can be '
            'relative or absolute)',
        valueHelp: 'path/to/foo/packages/foo/extension/devtools',
        mandatory: true,
      );
  }

  static const _sourceKey = 'source';
  static const _destinationKey = 'dest';

  @override
  String get name => 'build_and_copy';

  @override
  String get description =>
      'Command that builds a DevTools extension from source and copies the '
      'built output to the parent package extension location.';

  @override
  Future<void> run() async {
    final source = argResults?[_sourceKey]! as String;
    final destination = argResults?[_destinationKey]! as String;

    final processManager = ProcessManager();

    _log('Building the extension Flutter web app...');
    await _runProcess(
      processManager,
      'flutter',
      [
        'build',
        'web',
        '--web-renderer',
        'canvaskit',
        '--pwa-strategy=offline-first',
        '--release',
        '--no-tree-shake-icons',
      ],
      workingDirectory: source,
    );

    _log('Setting canvaskit permissions...');
    await _runProcess(
      processManager,
      'chmod',
      [
        '0755',
        // Note: using a wildcard `canvaskit.*` throws.
        'build/web/canvaskit/canvaskit.js',
        'build/web/canvaskit/canvaskit.wasm',
      ],
      workingDirectory: source,
    );

    _log('Copying built output to the extension destination...');
    await _copyBuildToDestination(source: source, dest: destination);

    // Closes stdin for the entire program.
    await sharedStdIn.terminate();
  }

  Future<void> _copyBuildToDestination({
    required String source,
    required String dest,
  }) async {
    _log('Copying the extension config.json file into a temp directory...');
    final tmp = Directory.current.createTempSync();
    final tmpConfigPath = path.join(tmp.path, 'config.json');
    final destinationConfigPath = path.join(dest, 'config.json');
    File(destinationConfigPath)..copySync(tmpConfigPath);

    _log('Replacing the existing extension build with the new one...');
    final sourceBuildPath = path.join(source, 'build', 'web');
    final destinationBuildPath = path.join(dest, 'build');
    Directory(destinationBuildPath)..deleteSync(recursive: true);
    Directory(destinationBuildPath)..createSync(recursive: true);
    await copyPath(
      sourceBuildPath,
      destinationBuildPath,
    );

    _log(
      'Copying the extension config.json file back to the destination '
      'directory...',
    );
    File(tmpConfigPath)..copySync(destinationConfigPath);
    tmp.deleteSync(recursive: true);

    _log(
      'Successfully copied extension assets from '
      '"${Directory(source).resolveSymbolicLinksSync()}" to'
      '"${Directory(dest).resolveSymbolicLinksSync()}"',
    );
  }

  void _log(String message) => print('[$name] $message');

  Future<void> _runProcess(
    ProcessManager processManager,
    String exe,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final buildProcess = await processManager.spawn(
      exe,
      args,
      workingDirectory: workingDirectory,
    );
    final code = await buildProcess.exitCode;
    if (code != 0) {
      throw ProcessException(exe, args, 'Failed with exit code: $code', code);
    }
  }
}
