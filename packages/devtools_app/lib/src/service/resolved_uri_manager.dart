// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../shared/globals.dart';

/// Manager for handling package Uri lookup and caching.
class ResolvedUriManager {
  _PackagePathMappings? _packagePathMappings;

  /// Initializes the [ResolvedUriManager]
  void vmServiceOpened() {
    _packagePathMappings = _PackagePathMappings();
  }

  /// Cleans up the resources of the [ResolvedUriManager]
  void vmServiceClosed() {
    _packagePathMappings = null;
  }

  /// Calls out to the [VmService] to lookup unknown full file path to package uri mappings.
  ///
  /// Known mappings are cached to avoid asking [VmService] redundantly.
  ///
  /// [isolateId] The id of the isolate that the [uris] were generated on.
  /// [uris] List of uris to fetch package uris for.
  Future<void> fetchPackageUris(String isolateId, List<String> uris) async {
    if (uris.isEmpty) return;
    if (_packagePathMappings != null) {
      final packageUris = (await serviceConnection.serviceManager.service!
              .lookupPackageUris(isolateId, uris))
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

  /// Calls out to the [VMService] to lookup package uri to full file path
  /// mappings
  ///
  /// Known mappings are cached to avoid asking [VmService] redundantly.
  ///
  /// [isolateId] The id of the isolate that the [packageUris] were generated on.
  /// [packageUris] List of uris to fetch full file paths for.
  Future<void> fetchFileUris(String isolateId, List<String> packageUris) async {
    if (_packagePathMappings != null) {
      final fileUris = (await serviceConnection.serviceManager.service!
              .lookupResolvedPackageUris(isolateId, packageUris))
          .uris;

      // [_packagePathMappings] could have been set to null during the async gap
      // so check that it is non-null again here.
      if (fileUris != null && _packagePathMappings != null) {
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

  String? lookupFileUri(String isolateId, String packageUri) =>
      _packagePathMappings?.lookupPackageToFullPathMapping(
        isolateId,
        packageUri,
      );
}

/// Helper class for storing 1:1 mappings for full file paths to package paths.
class _PackagePathMappings {
  final Map<String, Map<String, String?>> _isolatePackageToFullPathMappings =
      <String, Map<String, String?>>{};
  final Map<String, Map<String, String?>> _isolateFullPathToPackageMappings =
      <String, Map<String, String?>>{};

  /// Returns the package path to full path mapping if it has already
  /// been fetched.
  String? lookupPackageToFullPathMapping(
    String isolateId,
    String packagePath,
  ) =>
      _isolatePackageToFullPathMappings[isolateId]?[packagePath];

  /// Returns the full path to package path mapping if it has already
  /// been fetched.
  String? lookupFullPathToPackageMapping(
    String isolateId,
    String fullPath,
  ) =>
      _isolateFullPathToPackageMappings[isolateId]?[fullPath];

  /// Saves the mappings of [fullPaths] to [packagePaths].
  ///
  /// Each index of [fullPaths] maps to the same index in [packagePaths].
  /// The relationship is stored bidirectionally so that
  /// both [lookupFullPathToPackageMapping] and [lookupPackageToFullPathMapping]
  /// have access to the mapping.
  void addMappings({
    required String isolateId,
    required List<String?> fullPaths,
    required List<String?> packagePaths,
  }) {
    assert(fullPaths.length == packagePaths.length);
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
