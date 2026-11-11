// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../server_api.dart';

/// A namespace for DevTools extensions server request handlers.
extension _ExtensionsApiHandler on Never {
  static Future<shelf.Response> handleServeAvailableExtensions(
    ServerApi api,
    Map<String, String> queryParams,
    ExtensionsManager extensionsManager,
    DtdInfo? dtd,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [ExtensionsApi.packageRootUriPropertyName],
      queryParams: queryParams,
      api: api,
      requestName: ExtensionsApi.apiServeAvailableExtensions,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final logs = <String>[];
    final rootFileUriString =
        queryParams[ExtensionsApi.packageRootUriPropertyName];
    if (rootFileUriString != null && rootFileUriString.isNotEmpty) {
      final rootFileUri = Uri.tryParse(rootFileUriString);
      if (!rootFileUriString.startsWith('file://') ||
          rootFileUri == null ||
          rootFileUri.scheme != 'file' ||
          rootFileUri.host.isNotEmpty) {
        return api.badRequest(
          'Invalid ${ExtensionsApi.packageRootUriPropertyName}: must be a '
          'file:// URI with an empty host.',
        );
      }
    }
    final result = <String, Object?>{};

    /// Helper to return a success response with all available extensions
    /// detected by [extensionsManager].
    shelf.Response succeedWithAvailableExtensions({String? warning}) {
      final extensions = extensionsManager.devtoolsExtensions
          .map((p) => p.toJson())
          .toList();
      result[ExtensionsApi.extensionsResultPropertyName] = extensions;
      if (warning != null) {
        result[ExtensionsApi.extensionsResultWarningPropertyName] = warning;
      }
      return ServerApi._encodeResponse(
        ServerApi._wrapWithLogs(result, logs),
        api: api,
      );
    }

    try {
      await extensionsManager.serveAvailableExtensions(
        rootFileUriString,
        logs,
        dtd,
      );
    } on ExtensionParsingException catch (e) {
      // For [ExtensionParsingException]s, we should return a success response
      // with a warning message.
      result[ExtensionsApi.extensionsResultWarningPropertyName] = e.message;
    } catch (e) {
      // If any extensions were successfully detected, return a success response
      // with a warning.
      if (extensionsManager.devtoolsExtensions.isNotEmpty) {
        return succeedWithAvailableExtensions(warning: '$e');
      }
      return api.serverError('$e', logs);
    }

    return succeedWithAvailableExtensions();
  }

  static shelf.Response handleExtensionEnabledState(
    ServerApi api,
    Map<String, String> queryParams,
    ExtensionsManager extensionsManager,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [
        ExtensionsApi.devtoolsOptionsUriPropertyName,
        ExtensionsApi.extensionNamePropertyName,
      ],
      queryParams: queryParams,
      api: api,
      requestName: ExtensionsApi.apiExtensionEnabledState,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final devtoolsOptionsFileUriString =
        queryParams[ExtensionsApi.devtoolsOptionsUriPropertyName]!;
    final devtoolsOptionsFileUri = Uri.parse(devtoolsOptionsFileUriString);

    // Validate that the URI is a local file URI whose file name is exactly
    // 'devtools_options.yaml'. Accepting arbitrary URIs from the query string
    // would allow an untrusted caller to create or overwrite any file writable
    // by the DevTools server process. Resolving the name through
    // `Uri.toFilePath()` + `p.basename` handles both '/' and '\' path
    // separators, so the check holds for Windows file URIs as well. Requiring
    // an empty host rejects UNC paths (e.g. `file://server/share/...`) and
    // keeps `toFilePath()` from throwing on a non-local authority.
    final isFileUri =
        devtoolsOptionsFileUri.scheme == 'file' &&
        devtoolsOptionsFileUri.host.isEmpty;
    final fileName = isFileUri
        ? p.basename(devtoolsOptionsFileUri.toFilePath())
        : '';
    if (!isFileUri || fileName != devtoolsOptionsFileName) {
      return api.badRequest(
        'Invalid devtoolsOptionsUri: must be a file: URI named '
        "'$devtoolsOptionsFileName'.",
      );
    }

    final requestedOptionsPath = _resolveOptionsFilePath(
      devtoolsOptionsFileUri,
    );

    // Make sure that this extension's `devtools_options.yaml` file is
    // being served by [ExtensionsManager].
    //
    // This prevents DevTools from creating missing directories on disk when
    // this path points outside of the extension directory.
    final isServedExtensionOptionsFile =
        requestedOptionsPath != null &&
        extensionsManager.servedDevToolsOptionsUris.any((uriString) {
          final uri = Uri.tryParse(uriString);
          if (uri == null) return false;
          final servedPath = _resolveOptionsFilePath(uri);
          return servedPath != null &&
              p.equals(servedPath, requestedOptionsPath);
        });
    if (!isServedExtensionOptionsFile) {
      return api.badRequest(
        'Invalid devtoolsOptionsUri: must belong to a currently served '
        'DevTools extension.',
      );
    }

    final optionsFileUri = Uri.file(requestedOptionsPath);
    final extensionName = queryParams[ExtensionsApi.extensionNamePropertyName]!;
    final extensionPackage =
        queryParams[ExtensionsApi.extensionPackagePropertyName];

    final activate = queryParams[ExtensionsApi.enabledStatePropertyName];
    if (activate != null) {
      final newState = ServerApi._devToolsOptions.setExtensionEnabledState(
        devtoolsOptionsUri: optionsFileUri,
        extensionName: extensionName,
        packageName: extensionPackage,
        enable: bool.parse(activate),
      );
      return ServerApi._encodeResponse(newState.name, api: api);
    }
    final activationState = ServerApi._devToolsOptions
        .lookupExtensionEnabledState(
          devtoolsOptionsUri: optionsFileUri,
          extensionName: extensionName,
          packageName: extensionPackage,
        );
    return ServerApi._encodeResponse(activationState.name, api: api);
  }

  /// Resolves symbolic links on the parent directory of [uri] to return the
  /// absolute path to `devtools_options.yaml`.
  ///
  /// Returns the actual file path to `devtools_options.yaml`, or `null` if
  /// [uri] is not a local `file:` URI, its parent directory does not exist, or
  /// the `devtools_options.yaml` file itself is a symbolic link.
  static String? _resolveOptionsFilePath(Uri uri) {
    if (uri.scheme != 'file' || uri.host.isNotEmpty) return null;

    final filePath = p.normalize(uri.toFilePath());
    if (p.basename(filePath) != devtoolsOptionsFileName) return null;

    final parentDir = Directory(p.dirname(filePath));
    if (!parentDir.existsSync()) return null;

    try {
      final resolvedParent = p.normalize(parentDir.resolveSymbolicLinksSync());
      final resolvedFilePath = p.join(resolvedParent, devtoolsOptionsFileName);
      if (FileSystemEntity.isLinkSync(resolvedFilePath)) return null;
      return resolvedFilePath;
    } on FileSystemException {
      return null;
    }
  }
}
