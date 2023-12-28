// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:extension_discovery/extension_discovery.dart';
import 'package:path/path.dart' as path;

import 'extension_model.dart';

/// Location where DevTools extension assets will be served, relative to where
/// DevTools assets are served (build/).
const extensionRequestPath = 'devtools_extensions';

/// The default location for the DevTools extension, relative to
/// `<parent_package_root>/extension/devtools/`.
const extensionBuildDefault = 'build';

/// Responsible for storing the available DevTools extensions and managing the
/// content that DevTools server will serve at `build/devtools_extensions`.
///
/// When [serveAvailableExtensions] is called, the available extensions will be
/// looked up using package:extension_discovery, and the available extension's
/// assets will be copied to the `build/devtools_extensions` directory that
/// DevTools server is serving.
class ExtensionsManager {
  ExtensionsManager({required this.buildDir});

  /// The build directory of DevTools that is being served by the DevTools
  /// server.
  final String buildDir;

  /// The directory path where DevTools extensions are being served by the
  /// DevTools server.
  String get _servedExtensionsPath => path.join(buildDir, extensionRequestPath);

  /// The list of available DevTools extensions that are being served by the
  /// DevTools server.
  ///
  /// This list will be cleared and re-populated each time
  /// [serveAvailableExtensions] is called.
  final devtoolsExtensions = <DevToolsExtensionConfig>[];

  /// Serves any available DevTools extensions for the given [rootPathFileUri],
  /// where [rootPathFileUri] is the root for a Dart or Flutter project
  /// containing the `.dart_tool/` directory.
  ///
  /// [rootPathFileUri] is expected to be a file uri (e.g. starting with
  /// 'file://').
  ///
  /// This method first looks up the available extensions using
  /// package:extension_discovery, and the available extension's
  /// assets will be copied to the `build/devtools_extensions` directory that
  /// DevTools server is serving.
  Future<void> serveAvailableExtensions(String? rootPathFileUri) async {
    if (rootPathFileUri != null && !rootPathFileUri.startsWith('file://')) {
      throw ArgumentError.value(
        rootPathFileUri,
        'rootPathFileUri',
        'must be a file:// URI String',
      );
    }

    devtoolsExtensions.clear();
    final parsingErrors = StringBuffer();

    if (rootPathFileUri != null) {
      late final List<Extension> extensions;
      try {
        extensions = await findExtensions(
          'devtools',
          packageConfig: Uri.parse(
            path.posix.join(
              rootPathFileUri,
              '.dart_tool',
              'package_config.json',
            ),
          ),
        );
      } catch (e) {
        extensions = <Extension>[];
        rethrow;
      }

      for (final extension in extensions) {
        final config = extension.config;
        // TODO(https://github.com/dart-lang/pub/issues/4042): make this check
        // more robust.
        final isPubliclyHosted = (extension.rootUri.path.contains('pub.dev') ||
                extension.rootUri.path.contains('pub.flutter-io.cn'))
            .toString();

        // This should be relative to the 'extension/devtools/' directory and
        // defaults to 'build';
        final relativeExtensionLocation =
            config['buildLocation'] as String? ?? 'build';

        final location = path.join(
          extension.rootUri.toFilePath(),
          'extension',
          'devtools',
          relativeExtensionLocation,
        );

        try {
          final extensionConfig = DevToolsExtensionConfig.parse({
            ...config,
            DevToolsExtensionConfig.pathKey: location,
            DevToolsExtensionConfig.isPubliclyHostedKey: isPubliclyHosted,
          });
          devtoolsExtensions.add(extensionConfig);
        } on StateError catch (e) {
          parsingErrors.writeln(e.message);
          continue;
        }
      }
    }

    _resetServedPluginsDir();
    await Future.wait([
      for (final extension in devtoolsExtensions)
        _moveToServedExtensionsDir(extension.name, extension.path),
    ]);

    if (parsingErrors.isNotEmpty) {
      throw ExtensionParsingException(
        'Encountered errors while parsing extension config.yaml '
        'files:\n$parsingErrors',
      );
    }
  }

  void _resetServedPluginsDir() {
    final buildDirectory = Directory(buildDir);
    if (!buildDirectory.existsSync()) {
      throw const FileSystemException('The build directory does not exist.');
    }

    // Destroy and recreate the 'devtools_extensions' directory where extension
    // assets are served.
    final servedExtensionsDir = Directory(_servedExtensionsPath);
    if (servedExtensionsDir.existsSync()) {
      servedExtensionsDir.deleteSync(recursive: true);
    }
    servedExtensionsDir.createSync();
  }

  Future<void> _moveToServedExtensionsDir(
    String extensionPackageName,
    String extensionPath,
  ) async {
    final newExtensionPath = path.join(
      _servedExtensionsPath,
      extensionPackageName,
    );
    await copyPath(extensionPath, newExtensionPath);
  }
}

// NOTE: this code is copied from `package:io`:
// https://github.com/dart-lang/io/blob/master/lib/src/copy_path.dart.
/// Copies all of the files in the [from] directory to [to].
///
/// This is similar to `cp -R <from> <to>`:
/// * Symlinks are supported.
/// * Existing files are over-written, if any.
/// * If [to] is within [from], throws [ArgumentError] (an infinite operation).
/// * If [from] and [to] are canonically the same, no operation occurs.
///
/// Returns a future that completes when complete.
Future<void> copyPath(String from, String to) async {
  if (path.canonicalize(from) == path.canonicalize(to)) {
    return;
  }
  if (path.isWithin(from, to)) {
    throw ArgumentError('Cannot copy from $from to $to');
  }

  await Directory(to).create(recursive: true);
  await for (final file in Directory(from).list(recursive: true)) {
    final copyTo = path.join(to, path.relative(file.path, from: from));
    if (file is Directory) {
      await Directory(copyTo).create(recursive: true);
    } else if (file is File) {
      await File(file.path).copy(copyTo);
    } else if (file is Link) {
      await Link(copyTo).create(await file.target(), recursive: true);
    }
  }
}

/// Exception type for errors encountered while parsing DevTools extension
/// config.yaml files.
class ExtensionParsingException extends FormatException {
  const ExtensionParsingException(super.message);
}
