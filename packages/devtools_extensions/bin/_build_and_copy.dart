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
      Platform.isWindows ? 'flutter.bat' : 'flutter',
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

    // TODO(kenz): investigate if we need to perform a windows equivalent of
    // `chmod` or if we even need to perform `chmod` for linux / mac anymore.
    if (!Platform.isWindows) {
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
    }

    _log('Copying built output to the extension destination...');
    await _copyBuildToDestination(source: source, dest: destination);
  }

  Future<void> _copyBuildToDestination({
    required String source,
    required String dest,
  }) async {
    _log('Replacing the existing extension build with the new one...');
    final sourceBuildPath = path.join(source, 'build', 'web');
    final destinationBuildPath = path.join(dest, 'build');

    final destinationDirectory = Directory(destinationBuildPath);
    if (destinationDirectory.existsSync()) {
      destinationDirectory.deleteSync(recursive: true);
    }
    Directory(destinationBuildPath)..createSync(recursive: true);

    await copyPath(
      sourceBuildPath,
      destinationBuildPath,
    );

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
