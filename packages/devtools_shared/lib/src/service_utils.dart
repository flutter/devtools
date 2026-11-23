// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';
import 'package:dtd/dtd.dart';
import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart';

import 'utils/file_utils.dart';

class RegisteredService {
  const RegisteredService({required this.service, required this.title});

  final String service;
  final String title;
}

/// Flutter memory service registered by Flutter Tools.
///
/// We call this service to get version information about the Flutter Android
/// memory info using Android's ADB.
const flutterMemory = RegisteredService(
  service: 'flutterMemoryInfo',
  title: 'Flutter Memory Info',
);

const flutterListViews = '_flutter.listViews';

/// Flutter engine returns estimate how much memory is used by layer/picture
/// raster cache entries in bytes.
const flutterEngineRasterCache = '_flutter.estimateRasterCacheMemory';

/// Allowed URI schemes for VM service connections.
const _allowedVmServiceSchemes = {'http', 'https', 'ws', 'wss', 'sse', 'sses'};

/// Regular expression matching IPv4 loopback addresses (`127.0.0.0/8`).
final _ipv4LoopbackRegex = RegExp(
  r'^127(?:\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$',
);

/// Returns whether [host] is a loopback host (`localhost`, `::1`, or
/// an IPv4 address in `127.0.0.0/8`).
bool isLoopbackHost(String host) {
  final normalizedHost = host.toLowerCase();
  return normalizedHost == 'localhost' ||
      normalizedHost == '::1' ||
      _ipv4LoopbackRegex.hasMatch(normalizedHost);
}

/// Returns a normalized vm service uri.
///
/// Removes trailing characters, trailing url fragments, and decodes urls that
/// were accidentally encoded.
///
/// For example, given a [value] of http://127.0.0.1:60667/72K34Xmq0X0=/#/vm,
/// this method will return the URI http://127.0.0.1:60667/72K34Xmq0X0=/.
///
/// Returns `null` if the [Uri] parsed from [value] is not [Uri.isAbsolute]
/// (i.e., it has no scheme or it has a fragment), does not use an allowed
/// VM service scheme (`http`, `https`, `ws`, `wss`, `sse`, `sses`), or does
/// not target a loopback host (`localhost`, `127.x.x.x`, `::1`, or `[::1]`).
Uri? normalizeVmServiceUri(String value) {
  value = value.trim();

  // Clean up urls that have a devtools server's prefix, aka:
  // http://127.0.0.1:9101?uri=http%3A%2F%2F127.0.0.1%3A56142%2FHOwgrxalK00%3D%2F
  const uriParamToken = '?uri=';
  if (value.contains(uriParamToken)) {
    value = value.substring(
      value.indexOf(uriParamToken) + uriParamToken.length,
    );
  }

  // Cleanup encoded urls likely copied from the uri of an existing running
  // DevTools app.
  if (value.contains('%3A%2F%2F')) {
    try {
      value = Uri.decodeFull(value);
    } on ArgumentError {
      return null;
    }
  }
  final uri = Uri.tryParse(value.trim())?.removeFragment();
  if (uri == null || !uri.isAbsolute) {
    return null;
  }
  const allowedSchemes = _allowedVmServiceSchemes;
  if (!allowedSchemes.contains(uri.scheme) || !isLoopbackHost(uri.host)) {
    return null;
  }
  if (uri.path.endsWith('/')) return uri;
  return uri.replace(path: uri.path);
}

/// Extension methods on [VmService] for detecting the package root directory of
/// the connected application.
extension VmServicePackageRootExtension on VmService {
  /// Returns the package root directory file URI string for the main isolate,
  /// or `null` if it cannot be determined.
  ///
  /// This should be the directory up the tree from the debugging target that
  /// contains the `.dart_tool/package_config.json` file.
  ///
  /// This method contains special logic for detecting the package root for
  /// test targets (i.e., a VM service connection spawned from `dart test` or
  /// `flutter test`). This is because the main isolate for test targets is
  /// running the test runner, and not the test library itself, so extra work
  /// is needed to find the package root of the test target.
  Future<String?> rootPackageDirectoryForMainIsolate({
    DartToolingDaemon? dtd,
  }) async {
    final mainIsolate = await _detectMainIsolate;
    final rootLib = mainIsolate?.rootLib;
    final rootLibUri = rootLib?.uri;
    if (mainIsolate == null || rootLibUri == null) return null;

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
    if (packageRootUriString.endsWith('.dart') && rootLib?.id != null) {
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
          var packageConfig = evalResult.valueAsString;
          if (evalResult.valueAsStringIsTruncated == true &&
              evalResult.id != null) {
            final fullStringObj = await getObject(
              isolateId,
              evalResult.id!,
              offset: 0,
              count: evalResult.length,
            );
            if (fullStringObj is Instance) {
              packageConfig = fullStringObj.valueAsString;
            }
          }
          final packageConfigSuffix = p.posix.join(
            '.dart_tool',
            'package_config.json',
          );
          if (packageConfig != null &&
              packageConfig.endsWith(packageConfigSuffix)) {
            return p.posix.dirname(p.posix.dirname(packageConfig));
          }
        }
      } catch (_) {
        // Older versions of package:test don't define `packageConfigLocation`;
        // fall back to checking the `test` import prefix below.
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
      // Ignore errors; the caller will fall back to the root library URI.
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
  Future<Isolate?> get _detectMainIsolate async {
    final isolateRefs = (await getVM()).isolates;
    if (isolateRefs == null || isolateRefs.isEmpty) return null;
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
