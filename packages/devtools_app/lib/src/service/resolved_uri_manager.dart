// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../shared/globals.dart';
import 'vm_service_wrapper.dart';

/// Manager for handling package Uri lookup and caching.
class ResolvedUriManager {
  /// Maps isolate ids to the mappings of resolvedUrls to packageUris
  ///
  /// The map keys and values are as follows:
  /// `_isolateResolvedUrlMap[isolateId][resolvedUrl] = packageUrl`
  Map<String, Map<String, String?>>? _isolateResolvedUrlMap;

  /// Initializes the [ResolvedUriManager]
  void vmServiceOpened() {
    _isolateResolvedUrlMap = <String, Map<String, String?>>{};
  }

  /// Cleans up the resources of the [ResolvedUriManager]
  void vmServiceClosed() => _isolateResolvedUrlMap = null;

  /// Calls out to the [VmService] to lookup unknown uri to package uri mappings.
  ///
  /// Known uri mappings are cached to avoid asking [VmService] for the same
  /// mapping.
  ///
  /// [isolateId] The id of the isolate that the [uris] were generated on.
  /// [uris] List of uris to fetch package uris for.
  Future<void> fetchPackageUris(
    String isolateId,
    List<String> uris,
  ) async {
    if (_isolateResolvedUrlMap != null) {
      final packageUris =
          (await serviceManager.service!.lookupPackageUris(isolateId, uris))
              .uris;

      if (!_isolateResolvedUrlMap!.containsKey(isolateId)) {
        _isolateResolvedUrlMap![isolateId] = <String, String?>{};
      }
      final resolvedUrlMap = _isolateResolvedUrlMap![isolateId]!;
      if (packageUris != null) {
        for (var i = 0; i < uris.length; i++) {
          final resolvedUrl = uris[i];
          final packageUri = packageUris[i];
          if (packageUri != null) {
            resolvedUrlMap[resolvedUrl] = packageUri;
          }
        }
      }
    }
  }

  /// Returns a package uri for the given uri, if one exists in the cache.
  ///
  /// [isolateId] The id of the isolate that the [uris] were generated on.
  /// [uri] Absolute path uri to look up in the package uri mapping cache.
  String? lookupPackageUri(String isolateId, String uri) {
    return _isolateResolvedUrlMap?[isolateId]?[uri];
  }
}
