// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:dtd/dtd.dart';
import 'package:extension_discovery/extension_discovery.dart';
import 'package:path/path.dart' as path;

import '../server/server_api.dart';
import 'constants.dart';
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

  /// The depth to search the user's IDE workspace roots for projects with
  /// DevTools extensions.
  ///
  /// We use a larger depth than the default to reduce the risk of missing
  /// static extensions in the user's project.
  static const _staticExtensionsSearchDepth = 8;

  /// Returns the absolute path of the assets for the extension with identifier
  /// [extensionIdentifier].
  ///
  /// This caches values upon first request for faster lookup.
  String? lookupLocationFor(String extensionIdentifier) {
    return _extensionLocationsByIdentifier.putIfAbsent(
      extensionIdentifier,
      () => devtoolsExtensions
          .firstWhereOrNull((e) => e.identifier == extensionIdentifier)
          ?.extensionAssetsPath,
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
    DTDConnectionInfo? dtd,
  ) async {
    logs.add(
      'ExtensionsManager.serveAvailableExtensions for '
      'rootPathFileUri: $rootFileUriString',
    );

    _clear();
    final parsingErrors = StringBuffer();

    // Find all runtime extensions for [rootFileUriString], if non-null and
    // non-empty.
    if (rootFileUriString != null && rootFileUriString.isNotEmpty) {
      await _addExtensionsForRoot(
        rootFileUriString,
        logs: logs,
        parsingErrors: parsingErrors,
        staticContext: false,
      );
    }

    // Find all static extensions for the project roots, which are derived from
    // the Dart Tooling Daemon, and add them to [devtoolsExtensions].
    final dtdUri = dtd?.uri;
    if (dtdUri != null) {
      DartToolingDaemon? dartToolingDaemon;
      try {
        dartToolingDaemon = await DartToolingDaemon.connect(Uri.parse(dtdUri));
        final projectRoots = await dartToolingDaemon.getProjectRoots(
          depth: _staticExtensionsSearchDepth,
        );
        for (final root in projectRoots.uris ?? const <Uri>[]) {
          // Skip the runtime app root. These extensions have already been
          // added to [devtoolsExtensions].
          if (root.toString() == rootFileUriString) continue;

          await _addExtensionsForRoot(
            // TODO(https://github.com/dart-lang/pub/issues/4218): this logic
            // assumes that the .dart_tool folder containing the
            // package_config.json file is in the same directory as the
            // pubspec.yaml file (since `dartToolingDaemon.getProjectRoots`
            // returns all directories within the IDE workspace roots that have
            // a pubspec.yaml file). This may be an incorrect assumption for
            // monorepos.
            root.toString(),
            logs: logs,
            parsingErrors: parsingErrors,
            staticContext: true,
          );
        }
      } finally {
        await dartToolingDaemon?.close();
      }
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
    required bool staticContext,
  }) async {
    _assertUriFormat(rootFileUriString);
    late final List<Extension> extensions;
    try {
      // TODO(https://github.com/dart-lang/pub/issues/4218): this assumes that
      // the .dart_tool/package_config.json file is in the package root, which
      // may be an incorrect assumption for monorepos.
      final packageConfigPath = path.posix.join(
        rootFileUriString,
        '.dart_tool',
        'package_config.json',
      );
      extensions = await findExtensions(
        'devtools',
        packageConfig: Uri.parse(packageConfigPath),
      );
      logs.add(
        'ExtensionsManager._addExtensionsForRoot find extensions for '
        'config: $packageConfigPath, result: '
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
          DevToolsExtensionConfig.extensionAssetsPathKey: location,
          // TODO(kenz): for monorepos, we may want to store the
          // devtools_options.yaml at the same location as the workspace's
          // .dart_tool/package_config.json file.
          DevToolsExtensionConfig.devtoolsOptionsUriKey:
              path.join(rootFileUriString, devtoolsOptionsFileName),
          DevToolsExtensionConfig.isPubliclyHostedKey: isPubliclyHosted,
          DevToolsExtensionConfig.detectedFromStaticContextKey:
              staticContext.toString(),
        });
        devtoolsExtensions.add(extensionConfig);
      } on StateError catch (e) {
        parsingErrors.writeln(e.message);
        continue;
      }
    }
  }

  void _assertUriFormat(String? uriString) {
    if (uriString != null && !uriString.startsWith('file://')) {
      throw ArgumentError.value(uriString, 'must be a file:// URI String');
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
