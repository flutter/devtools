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
  /// This map is used to lookup package roots for a particular VM service when
  /// [handleNotifyForVmServiceConnection] is called for a VM service disconnect
  /// in DevTools app.
  ///
  /// If the Dart Tooling Daemon was not started by DevTools, this map will
  /// never be used.
  static final _packageRootsForVmServiceConnections = <String, Uri>{};

  /// Registers a cached [rootPackageUri] for [vmServiceUriAsString] in
  /// [_packageRootsForVmServiceConnections] for testing.
  @visibleForTesting
  static void setPackageRootForVmServiceForTesting(
    String vmServiceUriAsString,
    Uri rootPackageUri,
  ) {
    _packageRootsForVmServiceConnections[vmServiceUriAsString] = rootPackageUri;
  }

  /// Clears all cached package roots in [_packageRootsForVmServiceConnections]
  /// for testing.
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
  }) async {
    final Uri rootPackageUri;
    if (connected) {
      final cachedRoot =
          _packageRootsForVmServiceConnections[vmServiceUriAsString] ??
          _packageRootsForVmServiceConnections[vmServiceUri.toString()];
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

        final root = await vmService.rootPackageDirectoryForMainIsolate(dtd);
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
        _packageRootsForVmServiceConnections[vmServiceUriAsString] =
            rootPackageUri;
        _packageRootsForVmServiceConnections[vmServiceUri.toString()] =
            rootPackageUri;
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
      final cachedRootForVmService =
          _packageRootsForVmServiceConnections[vmServiceUriAsString] ??
          _packageRootsForVmServiceConnections[vmServiceUri.toString()];
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

extension on VmService {
  Future<String?> rootPackageDirectoryForMainIsolate(
    DartToolingDaemon? dtd,
  ) async {
    final mainIsolate = await _detectMainIsolate;
    final rootLib = mainIsolate.rootLib;
    final rootLibUri = rootLib?.uri;
    if (rootLibUri == null) return null;

    final fileUriString = (await lookupResolvedPackageUris(mainIsolate.id!, [
      rootLibUri,
    ])).uris?.first;
    if (fileUriString == null) return null;

    var packageRootUriString = await packageRootFromFileUriString(
      fileUriString,
      dtd: dtd,
    );

    // If a Dart library URI was returned, this may be a test target (i.e. a
    // VM service connection spawned from `dart test` or `flutter test`).
    if (packageRootUriString != null &&
        packageRootUriString.endsWith('.dart') &&
        rootLib?.id != null) {
      packageRootUriString =
          (await _lookupTestTargetPackageRoot(
            isolateId: mainIsolate.id!,
            rootLibraryId: rootLib!.id!,
            dtd: dtd,
          )) ??
          packageRootUriString;
    }

    return packageRootUriString;
  }

  Future<String?> _lookupTestTargetPackageRoot({
    required String isolateId,
    required String rootLibraryId,
    required DartToolingDaemon? dtd,
  }) async {
    try {
      final obj = await getObject(isolateId, rootLibraryId);
      if (obj is! Library) return null;

      try {
        final evalResult = await evaluate(
          isolateId,
          rootLibraryId,
          'packageConfigLocation',
        );
        if (evalResult is InstanceRef) {
          final packageConfig = evalResult.valueAsString;
          final packageConfigSuffix = p.posix.join(
            '.dart_tool',
            'package_config.json',
          );
          if (packageConfig != null &&
              packageConfig.endsWith(packageConfigSuffix)) {
            return packageConfig.substring(
              0,
              packageConfig.length - packageConfigSuffix.length - 1,
            );
          }
        }
      } catch (_) {
        // Fall back to import prefix lookup if evaluation fails.
      }

      final testTargetUri = (obj.dependencies ?? <LibraryDependency>[])
          .firstWhereOrNull((dep) => dep.prefix == 'test')
          ?.target
          ?.uri;
      if (testTargetUri != null) {
        final resolvedTargetUri = (await lookupResolvedPackageUris(isolateId, [
          testTargetUri,
        ])).uris?.first;
        if (resolvedTargetUri != null) {
          return await packageRootFromFileUriString(
            resolvedTargetUri,
            dtd: dtd,
          );
        }
      }
    } catch (_) {
      // Fail gracefully if the test target lookup fails.
    }
    return null;
  }

  /// Uses heuristics to detect the main isolate.
  ///
  /// Assumes an isolate is the main isolate if it meets any of the criteria in
  /// the following order:
  ///
  /// 1. The isolate is the main Flutter isolate.
  /// 2. The isolate has ':main(' in its name.
  /// 3. The isolate is the first in the list of isolates on the VM.
  Future<Isolate> get _detectMainIsolate async {
    final isolateRefs = (await getVM()).isolates!;
    final isolateCandidates = await isolateRefs
        .map((ref) async => (ref: ref, isolate: await getIsolate(ref.id!)))
        .wait;

    Isolate? mainIsolate;
    for (final isolate in isolateCandidates) {
      final isFlutterIsolate = (isolate.isolate.extensionRPCs ?? []).any(
        (ext) => ext.startsWith('ext.flutter'),
      );
      if (isFlutterIsolate) {
        mainIsolate = isolate.isolate;
        break;
      }
    }
    mainIsolate ??= isolateCandidates
        .firstWhereOrNull((isolate) => isolate.ref.name!.contains(':main('))
        ?.isolate;

    // Fallback to selecting the first isolate in the list.
    mainIsolate ??= isolateCandidates.first.isolate;

    return mainIsolate;
  }
}

@visibleForTesting
typedef DetectRootPackageResponse = ({bool success, String? message, Uri? uri});
