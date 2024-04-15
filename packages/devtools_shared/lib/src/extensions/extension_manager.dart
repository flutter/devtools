// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:extension_discovery/extension_discovery.dart';
import 'package:path/path.dart' as path;

import 'extension_model.dart';

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
  /// The list of available DevTools extensions that are being served by the
  /// DevTools server.
  ///
  /// This list will be cleared and re-populated each time
  /// [serveAvailableExtensions] is called.
  final devtoolsExtensions = <DevToolsExtensionConfig>[];

  final _extensionLocationsByIdentifier = <String, String?>{};

  /// Returns the absolute path of the assets for the extension with identifier
  /// [extensionIdentifier].
  ///
  /// This caches values upon first request for faster lookup.
  String? lookupLocationFor(String extensionIdentifier) {
    return _extensionLocationsByIdentifier.putIfAbsent(
      extensionIdentifier,
      () => devtoolsExtensions
          .firstWhereOrNull((e) => e.identifier == extensionIdentifier)
          ?.path,
    );
  }

  /// Serves any available DevTools extensions for the given
  /// [rootFileUriString], where [rootFileUriString] is the root for a Dart or
  /// Flutter project containing the `.dart_tool/` directory.
  ///
  /// [rootFileUriString] is expected to be a file URI string (e.g. starting
  /// with 'file://').
  ///
  /// This method first looks up the available extensions using
  /// package:extension_discovery, and the available extension's
  /// assets will be copied to the `build/devtools_extensions` directory that
  /// DevTools server is serving.
  Future<void> serveAvailableExtensions(
    String? rootFileUriString,
    List<String> logs,
  ) async {
    if (rootFileUriString != null && !rootFileUriString.startsWith('file://')) {
      throw ArgumentError.value(
        rootFileUriString,
        'rootPathFileUri',
        'must be a file:// URI String',
      );
    }

    logs.add(
      'ExtensionsManager.serveAvailableExtensions: '
      'rootPathFileUri: $rootFileUriString',
    );

    _clear();
    final parsingErrors = StringBuffer();

    // Find all runtime extensions for [rootFileUriString], if non-null.
    if (rootFileUriString != null) {
      await _addExtensionsForRoot(
        rootFileUriString,
        logs: logs,
        parsingErrors: parsingErrors,
      );
    }

    if (parsingErrors.isNotEmpty) {
      throw ExtensionParsingException(
        'Encountered errors while parsing extension config.yaml '
        'files:\n$parsingErrors',
      );
    }
  }

  /// Finds the available extensions for the package root at
  /// [rootFileUriString], generates [DevToolsExtensionConfig] objects, and adds
  /// them to [devtoolsExtensions].
  Future<void> _addExtensionsForRoot(
    String rootFileUriString, {
    required List<String> logs,
    required StringBuffer parsingErrors,
  }) async {
    late final List<Extension> extensions;
    try {
      extensions = await findExtensions(
        'devtools',
        packageConfig: Uri.parse(
          path.posix.join(
            rootFileUriString,
            '.dart_tool',
            'package_config.json',
          ),
        ),
      );
      logs.add(
        'ExtensionsManager.serveAvailableExtensions: findExtensionsResult  - '
        '${extensions.map((e) => e.package).toList()}',
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

  void _clear() {
    _extensionLocationsByIdentifier.clear();
    devtoolsExtensions.clear();
  }
}

/// Exception type for errors encountered while parsing DevTools extension
/// config.yaml files.
class ExtensionParsingException extends FormatException {
  const ExtensionParsingException(super.message);
}
