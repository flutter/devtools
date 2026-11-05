// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
        _sourceKey,
        help:
            'The source location for the extension flutter web app (can  be '
            'relative or absolute)',
        valueHelp: 'path/to/foo/packages/foo_devtools_extension',
        mandatory: true,
      )
      ..addOption(
        _destinationKey,
        help:
            'The destination location for the extension build output (can be '
            'relative or absolute)',
        valueHelp: 'path/to/foo/packages/foo/extension/devtools',
        mandatory: true,
      )
      ..addFlag(
        _treeShakeIconsKey,
        help:
            'Allow the compiler to tree-shake the icon fonts used by the '
            'extension. This is disabled by default to preserve backwards '
            'compatibility for extensions that create IconData dynamically.',
      )
      ..addFlag(
        _webResourcesCdnKey,
        help:
            'Load web engine resources (e.g. CanvasKit) from the Google CDN '
            'instead of bundling them in the extension build output. Pass '
            '--no-web-resources-cdn to bundle the resources the extension '
            'needs locally instead (for example for offline use).',
        defaultsTo: true,
      )
      ..addFlag(
        _pruneCdnCanvasKitKey,
        help:
            'Delete the bundled canvaskit/ directory from the copied '
            'extension build output. Only use this when the app is known to '
            'load all web engine resources from the CDN at runtime: the '
            'default `flutter build web` configuration with no custom '
            'bootstrap, no custom index.html initialization, and no runtime '
            'configuration that could select local resources. Cannot be '
            'combined with --no-web-resources-cdn.',
      );
  }

  static const _sourceKey = 'source';
  static const _destinationKey = 'dest';
  static const _treeShakeIconsKey = 'tree-shake-icons';
  static const _webResourcesCdnKey = 'web-resources-cdn';
  static const _pruneCdnCanvasKitKey = 'prune-cdn-canvaskit';

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
    final treeShakeIcons = argResults?[_treeShakeIconsKey] as bool;
    final webResourcesCdn = argResults?[_webResourcesCdnKey] as bool;
    final pruneCdnCanvasKit = argResults?[_pruneCdnCanvasKitKey] as bool;

    if (pruneCdnCanvasKit && !webResourcesCdn) {
      throw UsageException(
        '--$_pruneCdnCanvasKitKey cannot be combined with '
        '--no-$_webResourcesCdnKey because local CanvasKit resources are '
        'required when the CDN is disabled.',
        argParser.usage,
      );
    }

    final processManager = ProcessManager();

    _log('Building the extension Flutter web app...');
    await _runProcess(
      processManager,
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      [
        'build',
        'web',
        '--release',
        if (!treeShakeIcons) '--no-tree-shake-icons',
        if (!webResourcesCdn) '--no-web-resources-cdn',
      ],
      workingDirectory: source,
    );

    // TODO(kenz): investigate if we need to perform a windows equivalent of
    // `chmod` or if we even need to perform `chmod` for linux / mac anymore.
    if (!Platform.isWindows) {
      _log('Setting canvaskit permissions...');
      await _runProcess(processManager, 'chmod', [
        '0755',
        // Note: using a wildcard `canvaskit.*` throws.
        'build/web/canvaskit/canvaskit.js',
        'build/web/canvaskit/canvaskit.wasm',
      ], workingDirectory: source);
    }

    _log('Copying built output to the extension destination...');
    await _copyBuildToDestination(
      source: source,
      dest: destination,
      pruneCdnCanvasKit: pruneCdnCanvasKit,
    );
  }

  Future<void> _copyBuildToDestination({
    required String source,
    required String dest,
    required bool pruneCdnCanvasKit,
  }) async {
    _log('Replacing the existing extension build with the new one...');
    final sourceBuildPath = path.join(source, 'build', 'web');
    final destinationBuildPath = path.join(dest, 'build');

    final destinationDirectory = Directory(destinationBuildPath);
    if (destinationDirectory.existsSync()) {
      destinationDirectory.deleteSync(recursive: true);
    }
    Directory(destinationBuildPath).createSync(recursive: true);

    await copyPath(sourceBuildPath, destinationBuildPath);

    pruneCopiedBuildOutput(
      destinationBuildPath,
      pruneCdnCanvasKit: pruneCdnCanvasKit,
    );

    _log(
      'Successfully copied extension assets from '
      '"${Directory(source).resolveSymbolicLinksSync()}" to'
      '"${Directory(dest).resolveSymbolicLinksSync()}"',
    );
  }

  /// Removes files from the copied extension build output that are never
  /// requested at runtime (https://github.com/flutter/devtools/issues/9897).
  ///
  /// The Flutter tool copies every built web engine artifact into
  /// `build/web/canvaskit`, including files a given build can never load.
  /// Assets are only removed when they are proven unreachable, or when the
  /// caller explicitly asserts they are not needed:
  ///
  /// * `.js.symbols` debug files are only used by development tooling and
  ///   are never fetched at runtime, so they are always removed.
  /// * `skwasm`/`wimp` renderer files are only reachable when the output
  ///   contains a `.wasm` application artifact at the build root, which is
  ///   emitted only for `dart2wasm` builds (as `main.dart.wasm`, possibly
  ///   content-hashed). Its absence proves — independently of any mutable
  ///   bootstrap configuration — that the wasm renderer cannot be
  ///   selected, so those variants are removed.
  /// * The entire `canvaskit/` directory is removed only when
  ///   [pruneCdnCanvasKit] is enabled. Whether a build loads CanvasKit
  ///   locally or from the CDN depends on runtime configuration that
  ///   cannot be verified statically, so this aggressive prune is opt-in.
  ///   Callers must ensure the app uses the default `flutter build web`
  ///   CDN configuration with no custom bootstrap, `index.html`
  ///   initialization, or runtime configuration overrides.
  static void pruneCopiedBuildOutput(
    String destinationBuildPath, {
    required bool pruneCdnCanvasKit,
  }) {
    final canvaskitDir = Directory(
      path.join(destinationBuildPath, 'canvaskit'),
    );
    if (!canvaskitDir.existsSync()) return;

    var prunedBytes = 0;

    if (pruneCdnCanvasKit) {
      // Opt-in aggressive prune: the caller asserts every engine resource
      // is loaded remotely at runtime.
      for (final entity in canvaskitDir.listSync(recursive: true)) {
        if (entity is File) prunedBytes += entity.lengthSync();
      }
      canvaskitDir.deleteSync(recursive: true);
    } else {
      // Debug symbols are never fetched at runtime in any build mode.
      for (final entity in canvaskitDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.js.symbols')) {
          prunedBytes += entity.lengthSync();
          entity.deleteSync();
        }
      }

      if (!Directory(destinationBuildPath).listSync().whereType<File>().any(
        (file) => file.path.endsWith('.wasm'),
      )) {
        // No wasm application artifact exists in this output, so no
        // configuration can select the wasm renderer and its engine files
        // are unreachable. The local `canvaskit/`, `chromium/` and
        // `webparagraph/` variants are kept because the loader selects
        // between them at runtime based on browser support.
        for (final entity in canvaskitDir.listSync()) {
          if (entity is! File) continue;
          final name = path.basename(entity.path);
          if (name.startsWith('skwasm') || name.startsWith('wimp')) {
            prunedBytes += entity.lengthSync();
            entity.deleteSync();
          }
        }
      }
    }

    if (prunedBytes > 0) {
      _log(
        'Pruned ${(prunedBytes / (1024 * 1024)).toStringAsFixed(1)} MB of '
        'engine resources that the extension never loads at runtime.',
      );
    }
  }

  static void _log(String message) =>
      stdout.writeln('[build_and_copy] $message');

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
