// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../shared/globals.dart';

/// Manager for handling package Uri lookup and caching.
class ResolvedUriManager {
  /// Maps isolate ids to the mappings of resolvedUrls to packageUris
  ///
  /// The map keys and values are as follows:
  /// `_isolateResolvedUrlMap[isolateId][resolvedUrl] = packageUrl`
  _PackagePathMappings? _packagePathMappings;

  /// Initializes the [ResolvedUriManager]
  void vmServiceOpened() {
    _packagePathMappings = _PackagePathMappings();
  }

  /// Cleans up the resources of the [ResolvedUriManager]
  void vmServiceClosed() {
    _packagePathMappings = null;
  }

  /// Calls out to the [VmService] to lookup unknown uri to package uri mappings.
  ///
  /// Known uri mappings are cached to avoid asking [VmService] for the same
  /// mapping.
  ///
  /// [isolateId] The id of the isolate that the [uris] were generated on.
  /// [uris] List of uris to fetch package uris for.
  Future<void> fetchPackageUris(String isolateId, List<String> uris) async {
    if (_packagePathMappings != null) {
      final packageUris =
          (await serviceManager.service!.lookupPackageUris(isolateId, uris))
              .uris;

      if (packageUris != null) {
        _packagePathMappings!.addMappings(
          isolateId: isolateId,
          fullPaths: uris,
          packagePaths: packageUris,
        );
      }
    }
  }

  Future<void> fetchFileUris(String isolateId, List<String> packageUris) async {
    if (_packagePathMappings != null) {
      final fileUris = (await serviceManager.service!
              .lookupResolvedPackageUris(isolateId, packageUris))
          .uris;

      if (fileUris != null) {
        _packagePathMappings!.addMappings(
          isolateId: isolateId,
          fullPaths: fileUris,
          packagePaths: packageUris,
        );
      }
    }
  }

  /// Returns a package uri for the given uri, if one exists in the cache.
  ///
  /// [isolateId] The id of the isolate that the [uris] were generated on.
  /// [uri] Absolute path uri to look up in the package uri mapping cache.
  String? lookupPackageUri(String isolateId, String fileUri) =>
      _packagePathMappings?.lookupFullPathToPackageMapping(isolateId, fileUri);

  String? lookupFileUri(String isolateId, packageUri) => _packagePathMappings
      ?.lookupPackageToFullPathMapping(isolateId, packageUri);
}

class _PackagePathMappings {
  final Map<String, Map<String, String?>> _isolatePackageToFullPathMappings =
      <String, Map<String, String?>>{};
  final Map<String, Map<String, String?>> _isolateFullPathToPackageMappings =
      <String, Map<String, String?>>{};

  String? lookupPackageToFullPathMapping(
    String isolateId,
    String packagePath,
  ) =>
      _isolatePackageToFullPathMappings[isolateId]?[packagePath];
  String? lookupFullPathToPackageMapping(
    String isolateId,
    String fullPath,
  ) =>
      _isolateFullPathToPackageMappings[isolateId]?[fullPath];

  void addMappings({
    required String isolateId,
    required List<String?> fullPaths,
    required List<String?> packagePaths,
  }) {
    final fullPathToPackageMappings =
        _isolateFullPathToPackageMappings.putIfAbsent(
      isolateId,
      () => <String, String?>{},
    );
    final packageToFullPathMappings =
        _isolatePackageToFullPathMappings.putIfAbsent(
      isolateId,
      () => <String, String?>{},
    );

    assert(fullPaths.length == packagePaths.length);

    for (var i = 0; i < fullPaths.length; i++) {
      final fullPath = fullPaths[i];
      final packagePath = packagePaths[i];
      if (fullPath != null) {
        fullPathToPackageMappings[fullPath] = packagePath;
      }
      if (packagePath != null) {
        packageToFullPathMappings[packagePath] = fullPath;
      }
    }
  }
}
