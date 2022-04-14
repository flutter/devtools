import '../shared/globals.dart';
import 'vm_service_wrapper.dart';

/// Manager for handling package Uri lookup and caching.
class ResolvedUriManager {
  Map<String, String?>? _resolvedUrlMap;
  VmServiceWrapper? service;

  /// Initializes the [ResolvedUriManager]
  void vmServiceOpened() {
    _resolvedUrlMap = <String, String?>{};
  }

  /// Cleans up the resources of the [ResolvedUriManager]
  void vmServiceClosed() {
    _resolvedUrlMap = null;
  }

  /// Calls out to the [VmService] to lookup unknown uri to package uri mappings.
  ///
  /// Known uri mappings are cached to avoid asking [VmService] for the same
  /// mapping.
  ///
  /// [uris] List of uris to fetch package uris for.
  Future<void> fetchPackageUris(
    String isolateId,
    List<String> uris,
  ) async {
    if (_resolvedUrlMap != null) {
      final packageUris =
          (await serviceManager.service!.lookupPackageUris(isolateId, uris))
              .uris;
      if (packageUris != null) {
        for (var i = 0; i < uris.length; i++) {
          final unknownUri = uris[i];
          final packageUri = packageUris[i];
          if (packageUri != null) {
            _resolvedUrlMap![unknownUri] = packageUri;
          }
        }
      }
    }
  }

  /// Returns a package uri for the given uri, if one exists in the cache.
  ///
  /// [uri] Absolute path uri to look up in the package uri mapping cache.
  String? lookupPackageUri(String uri) {
    return _resolvedUrlMap?[uri];
  }
}
