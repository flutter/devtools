// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../server_api.dart';

/// A namespace for VM service related server request handlers.
@visibleForTesting
extension VmServiceHandler on Never {
  static const _pubspecYamlFileName = 'pubspec.yaml';
  static const _dartToolDirName = '.dart_tool';
  static const _packageConfigJsonFileName = 'package_config.json';
  static const _homeEnvVarKeys = ['HOME', 'USERPROFILE'];

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

  /// Returns whether [rootPackageUri] is a valid Dart or Flutter package root
  /// directory that can safely be registered as a DTD IDE workspace root.
  @visibleForTesting
  static bool isValidRootPackageUri(
    Uri rootPackageUri, {
    @visibleForTesting Map<String, String>? environment,
  }) =>
      _validateRootPackageUri(rootPackageUri, environment: environment) == null;

  /// Validates that [rootPackageUri] is a local `file://` URI pointing to an
  /// existing Dart or Flutter package directory, and not the filesystem root or
  /// the user's home directory.
  ///
  /// Returns `null` if [rootPackageUri] is valid, or an error message if it
  /// must be rejected.
  static String? _validateRootPackageUri(
    Uri rootPackageUri, {
    Map<String, String>? environment,
  }) {
    if (!isValidLocalFileUri(rootPackageUri)) {
      return 'Invalid package root URI ($rootPackageUri): must be a file:// '
          'URI with an empty host.';
    }

    final String dirPath;
    try {
      dirPath = p.normalize(rootPackageUri.toFilePath());
    } catch (e) {
      return 'Invalid package root URI ($rootPackageUri): $e';
    }

    if (p.equals(dirPath, p.rootPrefix(dirPath))) {
      return 'Invalid package root URI ($rootPackageUri): cannot be the '
          'filesystem root.';
    }

    final dir = Directory(dirPath);
    final resolvedDirPath = _tryResolveSymbolicLinks(dir);
    if (resolvedDirPath != null &&
        p.equals(resolvedDirPath, p.rootPrefix(resolvedDirPath))) {
      return 'Invalid package root URI ($rootPackageUri): cannot resolve to '
          'the filesystem root.';
    }

    if (_isUserHomeDirectory(
      dirPath,
      resolvedDirPath: resolvedDirPath,
      environment: environment ?? Platform.environment,
    )) {
      return 'Invalid package root URI ($rootPackageUri): cannot be the user '
          'home directory.';
    }

    if (!dir.existsSync()) {
      return 'Invalid package root URI ($rootPackageUri): directory does not '
          'exist.';
    }

    final hasPubspec = File(p.join(dirPath, _pubspecYamlFileName)).existsSync();
    final hasPackageConfig = File(
      p.join(dirPath, _dartToolDirName, _packageConfigJsonFileName),
    ).existsSync();
    if (!hasPubspec && !hasPackageConfig) {
      return 'Invalid package root URI ($rootPackageUri): directory does not '
          'contain $_pubspecYamlFileName or '
          '$_dartToolDirName/$_packageConfigJsonFileName.';
    }

    return null;
  }

  /// Returns whether [dirPath] (or its resolved target [resolvedDirPath])
  /// matches the current user's home directory from `HOME` or `USERPROFILE`.
  static bool _isUserHomeDirectory(
    String dirPath, {
    required String? resolvedDirPath,
    required Map<String, String> environment,
  }) {
    for (final envKey in _homeEnvVarKeys) {
      final homePath = environment[envKey];
      if (homePath == null || homePath.isEmpty) continue;
      final normalizedHome = p.normalize(homePath);
      if (p.equals(dirPath, normalizedHome) ||
          (resolvedDirPath != null &&
              p.equals(resolvedDirPath, normalizedHome))) {
        return true;
      }
      final resolvedHome = _tryResolveSymbolicLinks(Directory(normalizedHome));
      if (resolvedHome != null &&
          (p.equals(dirPath, resolvedHome) ||
              (resolvedDirPath != null &&
                  p.equals(resolvedDirPath, resolvedHome)))) {
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
    required DartToolingDaemon dtd,
  }) async {
    final Uri rootPackageUri;
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
        final validationError = _validateRootPackageUri(rootPackageUri);
        if (validationError != null) {
          return (success: false, message: validationError, uri: null);
        }
        _packageRootsForVmServiceConnections[vmServiceUriAsString] =
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
          _packageRootsForVmServiceConnections[vmServiceUriAsString];
      if (cachedRootForVmService == null) {
        // If there is no root to remove, there is nothing for us to do.
        return (success: true, message: null, uri: null);
      }
      final validationError = _validateRootPackageUri(cachedRootForVmService);
      if (validationError != null) {
        _packageRootsForVmServiceConnections.remove(vmServiceUriAsString);
        return (success: false, message: validationError, uri: null);
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
    final validationError = _validateRootPackageUri(rootFromVmService);
    if (validationError != null) {
      return api.badRequest(validationError);
    }
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
    DartToolingDaemon dtd,
  ) async {
    final fileUriString = await _rootLibraryForMainIsolate;
    return fileUriString != null
        ? await packageRootFromFileUriString(fileUriString, dtd: dtd)
        : null;
  }

  Future<String?> get _rootLibraryForMainIsolate async {
    final mainIsolate = await _detectMainIsolate;
    final rootLib = mainIsolate.rootLib?.uri;
    if (rootLib == null) return null;

    final fileUriAsString = (await lookupResolvedPackageUris(mainIsolate.id!, [
      rootLib,
    ])).uris?.first;
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
