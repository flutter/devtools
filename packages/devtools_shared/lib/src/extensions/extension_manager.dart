// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import 'extension_model.dart';

/// Location where DevTools extension assets will be served, relative to where
/// DevTools assets are served (build/).
const extensionRequestPath = 'devtools_extensions';

/// The location for the DevTools extension, relative to the parent package's
/// root.
const extensionLocation = 'extension/devtools';

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

  /// Serves any available DevTools extensions for the given [rootPath], where
  /// [rootPath] is the root for a Dart or Flutter project containing the
  /// `.dart_tool/` directory.
  /// 
  /// This method first looks up the available extensions using
  /// package:extension_discovery, and the available extension's
  /// assets will be copied to the `build/devtools_extensions` directory that
  /// DevTools server is serving.
  void serveAvailableExtensions(String? rootPath) {
    devtoolsExtensions.clear();

    if (rootPath != null) {
      // TODO(kenz): use 'findExtensions' from package:extension_discovery once it
      // is published.
      // final extensions = findExtensions(
      //   'devtools',
      //   packageConfig: '$rootPath/.dart_tool/package_config.json',
      // );
      final extensions = <_Extension>[];
      for (final extension in extensions) {
        final config = extension.config;
        if (config is! Map) {
          // Fail gracefully. Invalid content in the extension's config.json.
          continue;
        }
        final configAsMap = config as Map<String, Object?>;

        // This should be relative to the 'extension/devtools/' directory and
        // defaults to 'build';
        final relativeExtensionLocation =
            configAsMap['buildLocation'] as String? ?? 'build';

        final location = path.join(
          extension.rootUri.toFilePath(),
          extensionLocation,
          relativeExtensionLocation,
        );

        try {
          final pluginConfig = DevToolsExtensionConfig.parse({
            ...configAsMap,
            DevToolsExtensionConfig.pathKey: location,
          });
          devtoolsExtensions.add(pluginConfig);
        } on StateError catch (e) {
          print(e.message);
          continue;
        }
      }
    }

    _resetServedPluginsDir();
    for (final extension in devtoolsExtensions) {
      _moveToServedExtensionsDir(extension.name, extension.path);
    }
  }

  void _resetServedPluginsDir() {
    final buildDirectory = Directory(buildDir);
    if (!buildDirectory.existsSync()) {
      throw Exception('The build directory does not exist.');
    }

    // Destroy and recreate the 'devtools_extensions' directory where extension
    // assets are served.
    final servedExtensionsDir = Directory(_servedExtensionsPath);
    if (servedExtensionsDir.existsSync()) {
      servedExtensionsDir.deleteSync(recursive: true);
    }
    servedExtensionsDir.createSync();
  }

  void _moveToServedExtensionsDir(
    String extensionPackageName,
    String extensionPath,
  ) {
    final newExtensionPath = path.join(
      _servedExtensionsPath,
      extensionPackageName,
    );
    copyPathSync(extensionPath, newExtensionPath);
  }
}

/// TODO(kenz): remove this class. This is copied from
/// package:extension_discovery, which is drafed here:
/// https://github.com/dart-lang/tools/pull/129. Remove this temporary copy once
/// package:extension_discovery is published.
class _Extension {
  _Extension._({
    required this.package,
    required this.rootUri,
    required this.packageUri,
    required this.config,
  });

  final String package;
  final Uri rootUri;
  final Uri packageUri;
  final Object? config;
}
