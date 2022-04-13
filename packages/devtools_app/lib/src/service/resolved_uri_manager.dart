import '../shared/globals.dart';
import 'vm_service_wrapper.dart';

class ResolvedUriManager {
  Map<String, String?>? _resolvedUrlMap;
  VmServiceWrapper? service;

  void vmServiceOpened() {
    _resolvedUrlMap = <String, String?>{};
  }

  void vmServiceClosed() {
    _resolvedUrlMap = null;
  }

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

  String? lookupPackageUri(String uri) {
    return _resolvedUrlMap?[uri];
  }
}
