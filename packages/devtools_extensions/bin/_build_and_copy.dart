// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// The result of inspecting one file for `_flutter.buildConfig` literals.
///
/// `foundConfig` is true when at least one well-formed configuration literal
/// was found; `renderers` contains the `renderer` values of every `builds`
/// entry across all discovered literals. A null result means the
/// configuration cannot be statically proven safe.
typedef _BuildConfigInspection = ({bool foundConfig, Set<String> renderers});

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
        _pruneLocalCanvasKitKey,
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

  static const _commandName = 'build_and_copy';
  static const _sourceKey = 'source';
  static const _destinationKey = 'dest';
  static const _treeShakeIconsKey = 'tree-shake-icons';
  static const _webResourcesCdnKey = 'web-resources-cdn';
  static const _pruneLocalCanvasKitKey = 'prune-local-canvaskit';

  static const _canvaskitDirName = 'canvaskit';
  static const _jsSymbolsSuffix = '.js.symbols';
  static const _skwasmAssetPrefix = 'skwasm';
  static const _wimpAssetPrefix = 'wimp';
  static const _skwasmRendererName = 'skwasm';

  @override
  String get name => _commandName;

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
    final pruneLocalCanvasKit = argResults?[_pruneLocalCanvasKitKey] as bool;

    if (pruneLocalCanvasKit && !webResourcesCdn) {
      throw UsageException(
        '--$_pruneLocalCanvasKitKey cannot be combined with '
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
      pruneLocalCanvasKit: pruneLocalCanvasKit,
    );
  }

  Future<void> _copyBuildToDestination({
    required String source,
    required String dest,
    required bool pruneLocalCanvasKit,
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
      pruneLocalCanvasKit: pruneLocalCanvasKit,
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
  /// `canvaskit/`, including files a given build can never load. Assets are
  /// only removed when they are proven unreachable, or when the caller
  /// explicitly asserts they are not needed:
  ///
  /// * `.js.symbols` debug files are only used by development tooling and
  ///   are never fetched at runtime, so they are always removed.
  /// * `skwasm*`/`wimp*` renderer variants are removed only when every
  ///   `_flutter.buildConfig` found in `flutter_bootstrap.js` or
  ///   `index.html` provably contains no build with `"renderer": "skwasm"`.
  ///   The loader selects engine resources from that configuration, and a
  ///   Skwasm renderer can be selected by `dart2wasm` builds
  ///   (`flutter build web --wasm`) as well as by `dart2js` builds that opt
  ///   in through `--dart-define=FLUTTER_WEB_USE_SKIA=false
  ///   --dart-define=FLUTTER_WEB_USE_SKWASM=true` — neither of which requires
  ///   a root-level `.wasm` application artifact, so artifact presence alone
  ///   cannot prove the renderer is unreachable. When no readable
  ///   configuration is found, or any discovered configuration is dynamic,
  ///   malformed, or mutates `builds`, the variants are kept.
  /// * The entire `canvaskit/` directory is removed only when
  ///   [pruneLocalCanvasKit] is enabled. Whether a build loads CanvasKit
  ///   locally or from the CDN depends on runtime configuration that cannot
  ///   be verified statically, so this aggressive prune is opt-in. Callers
  ///   must ensure the app uses the default `flutter build web` CDN
  ///   configuration with no custom bootstrap, `index.html` initialization,
  ///   or runtime configuration overrides.
  @visibleForTesting
  static void pruneCopiedBuildOutput(
    String destinationBuildPath, {
    required bool pruneLocalCanvasKit,
  }) {
    final canvaskitDir = Directory(
      path.join(destinationBuildPath, _canvaskitDirName),
    );
    if (!canvaskitDir.existsSync()) return;

    var prunedBytes = 0;

    if (pruneLocalCanvasKit) {
      // Opt-in aggressive prune: the caller asserts every engine resource
      // is loaded remotely at runtime.
      for (final entity in canvaskitDir.listSync(recursive: true)) {
        if (entity is File) prunedBytes += entity.lengthSync();
      }
      canvaskitDir.deleteSync(recursive: true);
    } else {
      // Debug symbols are never fetched at runtime in any build mode.
      for (final entity in canvaskitDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith(_jsSymbolsSuffix)) {
          prunedBytes += entity.lengthSync();
          entity.deleteSync();
        }
      }

      if (_canPruneSkwasmAssets(destinationBuildPath)) {
        // The local `canvaskit/`, `chromium/` and `webparagraph/` variants
        // are kept because the loader selects between them at runtime based
        // on browser support.
        for (final entity in canvaskitDir.listSync()) {
          if (entity is! File) continue;
          final name = path.basename(entity.path);
          if (name.startsWith(_skwasmAssetPrefix) ||
              name.startsWith(_wimpAssetPrefix)) {
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

  /// Whether the `skwasm*`/`wimp*` engine variants in [buildPath] can be
  /// proven unreachable and removed.
  ///
  /// Returns false — keeping every variant — unless at least one readable
  /// `_flutter.buildConfig` is found across `flutter_bootstrap.js` and
  /// `index.html` and none of the discovered `builds` entries declare the
  /// `skwasm` renderer.
  static bool _canPruneSkwasmAssets(String buildPath) {
    var foundConfig = false;
    final renderers = <String>{};
    for (final fileName in const ['flutter_bootstrap.js', 'index.html']) {
      final file = File(path.join(buildPath, fileName));
      if (!file.existsSync()) continue;
      final inspection = _inspectBuildConfig(file.readAsStringSync());
      if (inspection == null) return false;
      foundConfig = foundConfig || inspection.foundConfig;
      renderers.addAll(inspection.renderers);
    }
    return foundConfig && !renderers.contains(_skwasmRendererName);
  }

  static final _buildConfigToken = RegExp(
    r'(?<![A-Za-z0-9_$.])(?:window\.)?_flutter\.buildConfig(?![A-Za-z0-9_$])',
  );

  // Matches access to the `builds` property or any computed property access
  // on `_flutter.buildConfig`, which could mutate the configuration that the
  // static analysis below relies on.
  static final _buildsAccessPattern = RegExp(
    r'^\s*(?:(?:\?\s*\.\s*|\.\s*)builds\b|(?:\?\.)?\s*\[)',
  );

  /// Statically extracts the renderer values of every
  /// `_flutter.buildConfig = {...}` literal in [content].
  ///
  /// Returns null when the configuration cannot be proven safe: a
  /// non-literal assignment (for example `_flutter.buildConfig =
  /// runtimeConfig`), malformed JSON, a `builds` value that is not a list of
  /// objects, or code that reads or mutates `builds` outside the emitted
  /// literals. Plain reads of the configuration (as performed by the Flutter
  /// loader itself) are ignored.
  static _BuildConfigInspection? _inspectBuildConfig(String content) {
    var foundConfig = false;
    final renderers = <String>{};
    for (final match in _buildConfigToken.allMatches(content)) {
      final rest = content.substring(match.end);
      final assignment = RegExp(r'^\s*=(?![=>])').firstMatch(rest);
      if (assignment == null) {
        if (_buildsAccessPattern.hasMatch(rest)) return null;
        continue;
      }
      final rhs = rest.substring(assignment.end);
      final openBrace = rhs.indexOf('{');
      if (openBrace < 0 || rhs.substring(0, openBrace).trim().isNotEmpty) {
        return null;
      }
      final jsonText = _extractJsonObject(rhs, openBrace);
      if (jsonText == null) return null;
      final Object? decoded;
      try {
        decoded = jsonDecode(jsonText);
      } on FormatException {
        return null;
      }
      if (decoded is! Map) return null;
      final builds = decoded['builds'];
      if (builds is! List) return null;
      foundConfig = true;
      for (final entry in builds) {
        if (entry is! Map) return null;
        final renderer = entry['renderer'];
        if (renderer is String) renderers.add(renderer);
      }
    }
    return (foundConfig: foundConfig, renderers: renderers);
  }

  /// Returns the balanced `{...}` literal starting at the `{` at [start] in
  /// [content], or null when the braces never balance (for example inside a
  /// string that is never terminated).
  static String? _extractJsonObject(String content, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < content.length; i++) {
      final unit = content.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == 0x5C) {
          escaped = true;
        } else if (unit == 0x22) {
          inString = false;
        }
        continue;
      }
      if (unit == 0x22) {
        inString = true;
      } else if (unit == 0x7B) {
        depth++;
      } else if (unit == 0x7D) {
        depth--;
        if (depth == 0) return content.substring(start, i + 1);
      }
    }
    return null;
  }

  static void _log(String message) =>
      stdout.writeln('[$_commandName] $message');

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
