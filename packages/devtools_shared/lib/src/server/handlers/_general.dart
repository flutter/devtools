// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

@visibleForTesting
abstract class Handler {
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

  static Future<shelf.Response> handleNotifyForVmServiceConnection(
    ServerApi api,
    Map<String, String> queryParams,
    DTDConnectionInfo? dtd,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [apiParameterValueKey, apiParameterVmServiceConnected],
      queryParams: queryParams,
      api: api,
      requestName: apiNotifyForVmServiceConnection,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final dtdUri = dtd?.uri;
    final dtdSecret = dtd?.secret;
    if (dtdUri == null || dtdSecret == null) {
      // If DevTools server did not start DTD, there is nothing for us to do.
      // This assertion may change in the future if the DevTools server has
      // other functionality that interacts with VM service connections from
      // DevTools app clients.
      return api.success();
    }

    final connectedAsString = queryParams[apiParameterVmServiceConnected]!;
    late bool connected;
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

    final detectRootResponse = await detectRootPackageForVmService(
      vmServiceUriAsString: vmServiceUriAsString,
      vmServiceUri: vmServiceUri,
      connected: connected,
      api: api,
    );
    if (detectRootResponse.success) {
      final rootUri = detectRootResponse.uri;
      if (rootUri == null) {
        return api.success();
      }
      return updateDtdWorkspaceRoots(
        dtd!,
        rootFromVmService: rootUri,
        connected: connected,
        api: api,
      );
    } else {
      return api.serverError(detectRootResponse.message);
    }
  }

  @visibleForTesting
  static Future<DetectRootPackageResponse> detectRootPackageForVmService({
    required String vmServiceUriAsString,
    required Uri vmServiceUri,
    required bool connected,
    required ServerApi api,
  }) async {
    late Uri rootPackageUri;
    if (connected) {
      // TODO(kenz): should we first try to lookup the root from
      // [_packageRootsForVmServiceConnections]? Could the root library of the
      // main isolate change during the lifetime of a VM service instance?

      VmService? vmService;
      try {
        vmService = await connect<VmService>(
          uri: vmServiceUri,
          finishedCompleter: Completer<void>(),
          serviceFactory: VmService.defaultFactory,
        );

        final root = await vmService.rootPackageDirectoryForMainIsolate;
        if (root == null) {
          return (
            success: false,
            message: 'No root library found for main isolate '
                '($vmServiceUriAsString).',
            uri: null,
          );
        }
        rootPackageUri = Uri.parse(root);
        _packageRootsForVmServiceConnections[vmServiceUriAsString] =
            rootPackageUri;
      } catch (e) {
        return (
          success: false,
          message: 'Error detecting project roots ($vmServiceUriAsString)\n$e',
          uri: null,
        );
      } finally {
        vmService = null;
      }
    } else {
      final cachedRootForVmService =
          _packageRootsForVmServiceConnections[vmServiceUriAsString];
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
    DTDConnectionInfo dtd, {
    required Uri rootFromVmService,
    required bool connected,
    required ServerApi api,
  }) async {
    DTDConnection? dtdConnection;
    try {
      dtdConnection = await DartToolingDaemon.connect(Uri.parse(dtd.uri!));
      final currentRoots = (await dtdConnection.getIDEWorkspaceRoots())
          .ideWorkspaceRoots
          .toSet();
      // Add or remove [rootFromVmService] depending on whether this was a
      // connect or disconnect notification.
      final newRoots = connected
          ? (currentRoots..add(rootFromVmService)).toList()
          : (currentRoots..remove(rootFromVmService)).toList();
      await dtdConnection.setIDEWorkspaceRoots(dtd.secret!, newRoots);
      return api.success();
    } catch (e) {
      return api.serverError('$e');
    } finally {
      await dtdConnection?.close();
    }
  }
}

extension on VmService {
  Future<String?> get rootPackageDirectoryForMainIsolate async {
    final fileUriString = await _rootLibraryForMainIsolate;
    return fileUriString != null
        ? packageRootFromFileUriString(fileUriString)
        : null;
  }

  Future<String?> get _rootLibraryForMainIsolate async {
    final mainIsolate = await _detectMainIsolate;
    final rootLib = mainIsolate.rootLib?.uri;
    if (rootLib == null) return null;

    final fileUriAsString =
        (await lookupResolvedPackageUris(mainIsolate.id!, [rootLib]))
            .uris
            ?.first;
    return fileUriAsString;
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
    final isolateCandidates =
        await Future.wait<({IsolateRef ref, Isolate isolate})>(
      isolateRefs.map(
        (ref) async => (ref: ref, isolate: await getIsolate(ref.id!)),
      ),
    );

    Isolate? mainIsolate;
    for (final isolate in isolateCandidates) {
      final isFlutterIsolate = (isolate.isolate.extensionRPCs ?? [])
          .any((ext) => ext.startsWith('ext.flutter'));
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

typedef DetectRootPackageResponse = ({bool success, String? message, Uri? uri});
