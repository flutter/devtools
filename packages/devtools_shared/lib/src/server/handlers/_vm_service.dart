// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../server_api.dart';

/// A namespace for VM service related server request handlers.
@visibleForTesting
extension VmServiceHandler on Never {
  /// File name of a Dart or Flutter package manifest.
  static const _pubspecYamlFileName = 'pubspec.yaml';

  /// Name of the Dart tooling metadata directory in a package root.
  static const _dartToolDirName = '.dart_tool';

  /// File name of the package configuration file inside [_dartToolDirName].
  static const _packageConfigJsonFileName = 'package_config.json';

  /// Environment variables holding the user's home directory on POSIX (`HOME`)
  /// and Windows (`USERPROFILE`).
  static const _homeEnvVarKeys = ['HOME', 'USERPROFILE'];

  /// Stores the calculated package roots for VM service connections that are
  /// initiated in [handleNotifyForVmServiceConnection].
  ///
  /// Entries are populated when [detectRootPackageForVmService] is called with
  /// `connected: true` and `cacheResult: true` (e.g., from
  /// [handleNotifyForVmServiceConnection] when DevTools server started DTD).
  ///
  /// This map is used both to avoid redundant VM service lookups (including
  /// from [_ExtensionsApiHandler.handleServeAvailableExtensions], which reads
  /// from this cache without populating it since callers like
  /// `ExtensionService(fixedVmServiceUri:)` do not send disconnect
  /// notifications) and to look up the root to remove when
  /// [handleNotifyForVmServiceConnection] is called for a VM service disconnect
  /// in DevTools app.
  static final _packageRootsForVmServiceConnections = <String, Uri>{};

  /// Caches [rootPackageUri] for [vmServiceUriAsString] in tests.
  @visibleForTesting
  static void setPackageRootForVmServiceForTesting(
    String vmServiceUriAsString,
    Uri rootPackageUri,
  ) {
    final normalizedUri = normalizeVmServiceUri(vmServiceUriAsString);
    if (normalizedUri == null) {
      throw ArgumentError.value(
        vmServiceUriAsString,
        'vmServiceUriAsString',
        'Cannot normalize VM service URI',
      );
    }
    _packageRootsForVmServiceConnections[normalizedUri.toString()] =
        rootPackageUri;
  }

  /// Clears cached package roots between tests.
  @visibleForTesting
  static void clearPackageRootsForTesting() {
    _packageRootsForVmServiceConnections.clear();
  }

  /// Validates that [rootPackageUri] is a local `file://` URI pointing to an
  /// existing Dart or Flutter package directory, and not the filesystem root or
  /// the user's home directory (or an ancestor of it).
  ///
  /// Returns the symlink-resolved [Uri] if [rootPackageUri] is valid, or an
  /// error message if it must be rejected.
  @visibleForTesting
  static ({Uri? resolvedUri, String? error}) validateRootPackageUri(
    Uri rootPackageUri, {
    Map<String, String>? environment,
  }) {
    if (!isValidLocalFileUri(rootPackageUri)) {
      return (
        resolvedUri: null,
        error:
            'Invalid package root URI ($rootPackageUri): '
            '$invalidLocalFileUriMessage',
      );
    }

    final dirPath = p.normalize(rootPackageUri.toFilePath());
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return (
        resolvedUri: null,
        error:
            'Invalid package root URI ($rootPackageUri): directory does not '
            'exist.',
      );
    }

    final String resolvedDirPath;
    try {
      resolvedDirPath = p.normalize(dir.resolveSymbolicLinksSync());
    } on FileSystemException catch (e) {
      return (
        resolvedUri: null,
        error:
            'Invalid package root URI ($rootPackageUri): failed to resolve '
            'symbolic links ($e).',
      );
    }

    if (p.equals(resolvedDirPath, p.rootPrefix(resolvedDirPath))) {
      return (
        resolvedUri: null,
        error:
            'Invalid package root URI ($rootPackageUri): cannot be the '
            'filesystem root.',
      );
    }

    if (_isUserHomeOrAncestorDirectory(
      resolvedDirPath,
      environment: environment ?? Platform.environment,
    )) {
      return (
        resolvedUri: null,
        error:
            'Invalid package root URI ($rootPackageUri): cannot be the user '
            'home directory or an ancestor of it.',
      );
    }

    final hasPubspec = File(
      p.join(resolvedDirPath, _pubspecYamlFileName),
    ).existsSync();
    final hasPackageConfig = File(
      p.join(resolvedDirPath, _dartToolDirName, _packageConfigJsonFileName),
    ).existsSync();
    if (!hasPubspec && !hasPackageConfig) {
      return (
        resolvedUri: null,
        error:
            'Invalid package root URI ($rootPackageUri): directory does not '
            'contain $_pubspecYamlFileName or '
            '$_dartToolDirName/$_packageConfigJsonFileName.',
      );
    }

    return (resolvedUri: Uri.file(resolvedDirPath), error: null);
  }

  /// Returns whether [resolvedDirPath] matches or is an ancestor of the
  /// current user's home directory from `HOME` or `USERPROFILE`.
  static bool _isUserHomeOrAncestorDirectory(
    String resolvedDirPath, {
    required Map<String, String> environment,
  }) {
    for (final envKey in _homeEnvVarKeys) {
      final homePath = environment[envKey];
      if (homePath == null || homePath.isEmpty) continue;
      final normalizedHome = p.normalize(homePath);
      final resolvedHome =
          _tryResolveSymbolicLinks(Directory(normalizedHome)) ?? normalizedHome;
      if (p.equals(resolvedDirPath, resolvedHome) ||
          p.isWithin(resolvedDirPath, resolvedHome)) {
        return true;
      }
    }
    return false;
  }

  /// Resolves symbolic links for [directory] if it exists, returning `null` if
  /// it does not exist or resolution fails.
  static String? _tryResolveSymbolicLinks(Directory directory) {
    if (!directory.existsSync()) return null;
    try {
      return p.normalize(directory.resolveSymbolicLinksSync());
    } on FileSystemException {
      return null;
    }
  }

  /// Handles an [apiNotifyForVmServiceConnection] request notifying the
  /// DevTools server that a DevTools client connected to or disconnected from a
  /// VM service.
  ///
  /// Expects [queryParams] to contain [apiParameterValueKey] (the VM service
  /// URI) and [apiParameterVmServiceConnected] (`'true'` or `'false'`).
  ///
  /// When the DevTools server owns the Dart Tooling Daemon (DevTools was
  /// launched outside of the IDE, and [dtd] has both a [DtdInfo.localUri] and a
  /// [DtdInfo.secret]), this registers or unregisters the VM service with DTD,
  /// resolves and validates the app's package root via
  /// [detectRootPackageForVmService], and updates DTD's IDE workspace roots via
  /// [updateDtdWorkspaceRoots].
  ///
  /// Returns a [ServerApi.success] no-op response via [api] if [dtd] is
  /// unavailable or has no secret, [ServerApi.badRequest] if required
  /// parameters are missing or invalid, or [ServerApi.serverError] if package
  /// root detection or DTD communication fails.
  static Future<shelf.Response> handleNotifyForVmServiceConnection(
    ServerApi api,
    Map<String, String> queryParams,
    DtdInfo? dtd,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      const [apiParameterValueKey, apiParameterVmServiceConnected],
      queryParams: queryParams,
      api: api,
      requestName: apiNotifyForVmServiceConnection,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final dtdUri = dtd?.localUri;
    final dtdSecret = dtd?.secret;
    if (dtdUri == null || dtdSecret == null) {
      // If DevTools server did not start DTD, there is nothing for us to do.
      // This assertion may change in the future if the DevTools server has
      // other functionality that interacts with VM service connections from
      // DevTools app clients.
      return api.success();
    }

    final connectedAsString = queryParams[apiParameterVmServiceConnected]!;
    final bool connected;
    try {
      connected = bool.parse(connectedAsString);
    } catch (e) {
      return api.badRequest(
        'Cannot parse $apiParameterVmServiceConnected parameter:\n$e',
      );
    }

    final vmServiceUriAsString = queryParams[apiParameterValueKey]!;
    final vmServiceUri = normalizeVmServiceUri(vmServiceUriAsString);
    if (vmServiceUri == null) {
      return api.badRequest(
        'Cannot normalize VM service URI: $vmServiceUriAsString',
      );
    }

    DartToolingDaemon? dartToolingDaemon;
    try {
      dartToolingDaemon = await DartToolingDaemon.connect(dtd!.localUri);

      // ignore: unnecessary_null_comparison, intentionally added to guard against future logic changes.
      if (dtdSecret != null) {
        final uriAsString = vmServiceUri.toString();
        connected
            ? await dartToolingDaemon.registerVmService(
                uri: uriAsString,
                secret: dtdSecret,
              )
            : await dartToolingDaemon.unregisterVmService(
                uri: uriAsString,
                secret: dtdSecret,
              );
      }

      final detectRootResponse = await detectRootPackageForVmService(
        vmServiceUriAsString: vmServiceUriAsString,
        vmServiceUri: vmServiceUri,
        connected: connected,
        dtd: dartToolingDaemon,
      );
      if (detectRootResponse.success) {
        final rootUri = detectRootResponse.uri;
        if (rootUri == null) {
          return api.success();
        }
        return await updateDtdWorkspaceRoots(
          dartToolingDaemon,
          dtdConnectionInfo: dtd,
          rootFromVmService: rootUri,
          connected: connected,
          api: api,
        );
      } else {
        return api.serverError(detectRootResponse.message);
      }
    } catch (e) {
      return api.serverError('$e');
    } finally {
      await dartToolingDaemon?.close();
    }
  }

  @visibleForTesting
  static Future<DetectRootPackageResponse> detectRootPackageForVmService({
    required String vmServiceUriAsString,
    required Uri vmServiceUri,
    required bool connected,
    required DartToolingDaemon? dtd,
    bool cacheResult = true,
  }) async {
    final normalizedUriAsString = vmServiceUri.toString();
    final Uri rootPackageUri;
    if (connected) {
      final cachedRoot =
          _packageRootsForVmServiceConnections[normalizedUriAsString];
      if (cachedRoot != null) {
        return (success: true, message: null, uri: cachedRoot);
      }

      VmService? vmService;
      try {
        vmService = await connect<VmService>(
          uri: vmServiceUri,
          finishedCompleter: Completer<void>(),
          serviceFactory: VmService.defaultFactory,
        );

        final root = await vmService.rootPackageDirectoryForMainIsolate(
          dtd: dtd,
        );
        if (root == null) {
          return (
            success: false,
            message:
                'No root library found for main isolate '
                '($vmServiceUriAsString).',
            uri: null,
          );
        }
        final parsedRoot = Uri.tryParse(root);
        if (parsedRoot == null) {
          return (
            success: false,
            message:
                'Invalid package root URI ($root): '
                '$invalidLocalFileUriMessage',
            uri: null,
          );
        }
        final validationResult = validateRootPackageUri(parsedRoot);
        if (validationResult.error != null) {
          return (success: false, message: validationResult.error, uri: null);
        }
        rootPackageUri = validationResult.resolvedUri!;
        if (cacheResult) {
          _packageRootsForVmServiceConnections[normalizedUriAsString] =
              rootPackageUri;
        }
      } catch (e) {
        return (
          success: false,
          message: 'Error detecting project roots ($vmServiceUriAsString)\n$e',
          uri: null,
        );
      } finally {
        await vmService?.dispose();
        vmService = null;
      }
    } else {
      final cachedRootForVmService = _packageRootsForVmServiceConnections
          .remove(normalizedUriAsString);
      if (cachedRootForVmService == null) {
        // If there is no root to remove, there is nothing for us to do.
        return (success: true, message: null, uri: null);
      }
      rootPackageUri = cachedRootForVmService;
    }
    return (success: true, message: null, uri: rootPackageUri);
  }

  @visibleForTesting
  static Future<shelf.Response> updateDtdWorkspaceRoots(
    DartToolingDaemon dtd, {
    required DtdInfo dtdConnectionInfo,
    required Uri rootFromVmService,
    required bool connected,
    required ServerApi api,
  }) async {
    final currentRoots = (await dtd.getIDEWorkspaceRoots()).ideWorkspaceRoots
        .toSet();
    // Add or remove [rootFromVmService] depending on whether this was a
    // connect or disconnect notification.
    final newRoots = connected
        ? (currentRoots..add(rootFromVmService)).toList()
        : (currentRoots..remove(rootFromVmService)).toList();
    await dtd.setIDEWorkspaceRoots(dtdConnectionInfo.secret!, newRoots);
    return api.success();
  }
}

@visibleForTesting
typedef DetectRootPackageResponse = ({bool success, String? message, Uri? uri});
