import '../shared/globals.dart';
import 'vm_service_wrapper.dart';

class ResolvedUriManager {
  final _resolvedUrlMap = <String, String?>{};
  VmServiceWrapper? service;

  Future<void> fetchPackageUris(
    String isolateId,
    List<String> uris,
  ) async {
    final packageUris =
        (await serviceManager.service!.lookupPackageUris(isolateId, uris)).uris;
    if (packageUris != null) {
      for (var i = 0; i < uris.length; i++) {
        final unknownUri = uris[i];
        final resolvedUri = packageUris[i];
        _resolvedUrlMap[unknownUri] = resolvedUri!;
      }
    }
  }

  String? lookupPackageUri(String uri) {
    return _resolvedUrlMap[uri];
  }
}
