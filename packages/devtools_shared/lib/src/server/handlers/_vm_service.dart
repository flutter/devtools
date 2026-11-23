// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../server_api.dart';

/// A namespace for VM service related server request handlers.
@visibleForTesting
extension VmServiceHandler on Never {
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
  ///
  /// Entries are evicted on disconnect in [handleNotifyForVmServiceConnection]
  /// even if the Dart Tooling Daemon was not started by DevTools.
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
      // Even when DevTools server did not start DTD, evict any cached package
      // root on disconnect so stale entries are not retained.
      final connected = bool.tryParse(
        queryParams[apiParameterVmServiceConnected]!,
      );
      if (connected == false) {
        final vmServiceUri = normalizeVmServiceUri(
          queryParams[apiParameterValueKey]!,
        );
        if (vmServiceUri != null) {
          _packageRootsForVmServiceConnections.remove(vmServiceUri.toString());
        }
      }
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
        rootPackageUri = Uri.parse(root);
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
