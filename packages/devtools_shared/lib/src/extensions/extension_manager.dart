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

/// Mark copied from package:extension_discovery. Remove once it is published.

/// Information about an extension for target package.
class Extension {
  Extension._({
    required this.package,
    required this.rootUri,
    required this.packageUri,
    required this.config,
  });

  /// Name of the package providing an extension.
  final String package;

  /// Absolute path to the package root.
  ///
  /// This folder usually contains a `lib/` folder and a `pubspec.yaml`
  /// (assuming dependencies are fetched using the pub package manager).
  ///
  /// **Examples:** If `foo` is installed in pub-cache this would be:
  ///  * `/home/my_user/.pub-cache/hosted/pub.dev/foo-1.0.0/`
  ///
  /// See `rootUri` in the [specification for `package_config.json`][1],
  /// for details.
  ///
  /// [1]: https://github.com/dart-lang/language/blob/main/accepted/2.8/language-versioning/package-config-file-v2.md
  final Uri rootUri;

  /// Path to the library import path relative to [rootUri].
  ///
  /// In Dart code the `package:<package>/<path>` will be resolved as
  /// `<rootUri>/<packageUri>/<path>`.
  ///
  /// If dependencies are installed using `dart pub`, then this is
  /// **always** `lib/`.
  ///
  /// See `packageUri` in the [specification for `package_config.json`][1],
  /// for details.
  ///
  /// [1]: https://github.com/dart-lang/language/blob/main/accepted/2.8/language-versioning/package-config-file-v2.md
  final Uri packageUri;

  /// Contents of `extension/<targetPackage>/config.json` parsed as JSON.
  ///
  /// If parsing JSON from this file failed, then no [Extension] entry
  /// will exist.
  ///
  /// This field is always a structure consisting of the following types:
  ///  * `null`,
  ///  * [bool] (`true` or `false`),
  ///  * [String],
  ///  * [num] ([int] or [double]),
  ///  * [List<Object?>], and,
  ///  * [Map<String, Object?>].
  final Object? config;
}
