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

class ExtensionsManager {
  ExtensionsManager({required this.buildDir});

  final String buildDir;

  String get servedExtensionsPath => path.join(buildDir, extensionRequestPath);

  final devtoolsExtensions = <DevToolsExtensionConfig>[];

  void serveAvailableExtensions(String? rootPath) {
    devtoolsExtensions.clear();

    if (rootPath != null) {
      // TODO(kenz): use 'findExtensions' from package:extension_discovery once it
      // is published.
      // final extensions = findExtensions(
      //   'devtools',
      //   packageConfig: '$rootPath/.dart_tool/package_config.json',
      // );
      final extensions = <Extension>[];
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

        // TODO(kenz): this is hacky. Unclear if this will work for windows.
        var rootWithoutFile = extension.rootUri.toString();
        if (rootWithoutFile.startsWith('file:///Users')) {
          rootWithoutFile = rootWithoutFile.replaceFirst('file:///', '/');
        }

        final location = path.join(
          rootWithoutFile,
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
    final servedExtensionsDir = Directory(servedExtensionsPath);
    if (servedExtensionsDir.existsSync()) {
      servedExtensionsDir.deleteSync(recursive: true);
    }
    servedExtensionsDir.createSync();
  }

  void _moveToServedExtensionsDir(
    String extensionPackageName,
    String extensionPath,
  ) {
    final newExtensionPath =
        path.join(servedExtensionsPath, extensionPackageName);
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
