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
      )
      ..addOption(
        'dest',
        help: 'The destination location for the extension build output (can be '
            'relative or absolute)',
        valueHelp: 'path/to/foo/packages/foo/extension/devtools',
      );
  }

  static const _sourceKey = 'source';
  static const _destinationKey = 'dest';

  String get _logPrefix => '[$name]';

  @override
  final name = 'build_and_copy';

  @override
  final description =
      'Command that builds a DevTools extension from source and copies the '
      'built output to the parent package extension location.';

  @override
  Future<void> run() async {
    final source = argResults?[_sourceKey];
    final destination = argResults?[_destinationKey];
    if (source == null) {
      throw ArgumentError(
        'Missing argument \'$_sourceKey\', which describes the source location '
        'for the extension flutter web app',
        _sourceKey,
      );
    }
    if (destination == null) {
      throw ArgumentError(
        'Missing argument \'$_destinationKey\', which describes the source '
        'location for the extension flutter web app',
        _destinationKey,
      );
    }

    final processManager = ProcessManager();

    _log('building the extension flutter web app...');
    final buildProcess = await processManager.spawn(
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
    await buildProcess.exitCode;

    _log('setting canvaskit permissions...');
    final chmodProcess = await processManager.spawn(
      'chmod',
      ['0755', 'build/web/canvaskit/canvaskit.*'],
      workingDirectory: source,
    );
    await chmodProcess.exitCode;

    _log('copying built output to the extension destination...');
    await _copyBuildToDestination(source: source, dest: destination);

    // Closes stdin for the entire program.
    await sharedStdIn.terminate();
  }

  Future<void> _copyBuildToDestination({
    required String source,
    required String dest,
  }) async {
    _log('copying the extension config.json file into a temp directory...');
    final tmp = Directory.current.createTempSync();
    final tmpConfigPath = path.join(tmp.path, 'config.json');
    final destinationConfigPath = path.join(dest, 'config.json');
    File(destinationConfigPath)..copySync(tmpConfigPath);

    _log('replacing the existing extension build with the new one...');
    final sourceBuildPath = path.join(source, 'build', 'web');
    final destinationBuildPath = path.join(dest, 'build');
    Directory(destinationBuildPath)..deleteSync(recursive: true);
    Directory(destinationBuildPath)..createSync(recursive: true);
    await copyPath(
      sourceBuildPath,
      destinationBuildPath,
    );

    _log(
      'copying the extension config.json file back to the destination '
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

  void _log(String message) {
    print('$_logPrefix $message');
  }
}
