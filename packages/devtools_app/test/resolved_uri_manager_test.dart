// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/service/resolved_uri_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() async {
  group('ResolvedUriManager', () {
    const String isolateId = 'anIsolateId';
    ResolvedUriManager? resolvedUriManager;

    setUp(() {
      final service = MockVmService();
      when(service.onDebugEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onVMEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onIsolateEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onStdoutEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onStderrEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      setGlobal(ServiceConnectionManager, FakeServiceManager(service: service));
      resolvedUriManager = ResolvedUriManager();
    });

    test('lookupPackageUri when uri is unknown', () {
      final packageUriResult = resolvedUriManager!.lookupPackageUri('some/uri');
      expect(packageUriResult, isNull);
    });

    test('lookupPackageUris', () async {
      const uri1 = 'this/is/a/uri1';
      const uri2 = 'this/is/a/uri2';
      const packageUri1 = 'uri/am/i1';
      const packageUri2 = 'uri/am/i2';
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri1, uri2]))
          .thenAnswer(
        (realInvocation) =>
            Future.value(UriList(uris: [packageUri1, packageUri2])),
      );

      await resolvedUriManager!.fetchPackageUris(isolateId, [uri1, uri2]);

      expect(resolvedUriManager!.lookupPackageUri(uri1), equals(packageUri1));
      expect(resolvedUriManager!.lookupPackageUri(uri2), equals(packageUri2));
    });

    test('remembers already fetched uris', () async {
      const uri1 = 'this/is/a/uri1';
      const uri2 = 'this/is/a/uri2';
      const packageUri1 = 'uri/am/i1';
      const packageUri2 = 'uri/am/i2';
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri1]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri2]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri2])),
      );

      await resolvedUriManager!.fetchPackageUris(isolateId, [uri1]);
      expect(resolvedUriManager!.lookupPackageUri(uri1), equals(packageUri1));

      await resolvedUriManager!.fetchPackageUris(isolateId, [uri2]);
      expect(resolvedUriManager!.lookupPackageUri(uri1), equals(packageUri1));
      expect(resolvedUriManager!.lookupPackageUri(uri2), equals(packageUri2));
    });
  });
}
