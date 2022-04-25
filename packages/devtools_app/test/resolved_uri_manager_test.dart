// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/service/resolved_uri_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() async {
  late ResolvedUriManager resolvedUriManager;
  final service = MockVmServiceWrapper();

  when(service.getFlagList())
      .thenAnswer((_) => Future.value(FlagList(flags: [])));
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

  const String isolateId = 'anIsolateId';
  const uri1 = 'this/is/a/uri1';
  const uri2 = 'this/is/a/uri2';
  const packageUri1 = 'uri/am/i1';
  const packageUri2 = 'uri/am/i2';

  group('lifecycle', () {
    setUp(() {
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri1]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );
    });

    test('does nothing before vmServiceOpened', () async {
      await resolvedUriManager.fetchPackageUris(isolateId, [uri1]);

      expect(resolvedUriManager.lookupPackageUri(isolateId, uri1), isNull);
      verifyNever(service.lookupPackageUris('', []));
    });

    test('does nothing after vmServiceClosed', () async {
      resolvedUriManager.vmServiceOpened();
      resolvedUriManager.vmServiceClosed();

      await resolvedUriManager.fetchPackageUris(isolateId, [uri1]);

      expect(resolvedUriManager.lookupPackageUri(isolateId, uri1), isNull);
      verifyNever(service.lookupPackageUris('', []));
    });
  });

  group('general use', () {
    setUp(() {
      resolvedUriManager.vmServiceOpened();
    });
    test('lookupPackageUri when uri is unknown', () {
      final packageUriResult =
          resolvedUriManager.lookupPackageUri(isolateId, 'some/uri');
      expect(packageUriResult, isNull);
    });

    test('lookupPackageUris', () async {
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri1, uri2]))
          .thenAnswer(
        (realInvocation) =>
            Future.value(UriList(uris: [packageUri1, packageUri2])),
      );

      await resolvedUriManager.fetchPackageUris(isolateId, [uri1, uri2]);

      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri1),
        equals(packageUri1),
      );
      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri2),
        equals(packageUri2),
      );
    });

    test('remembers already fetched uris', () async {
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri1]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri2]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri2])),
      );

      await resolvedUriManager.fetchPackageUris(isolateId, [uri1]);
      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri1),
        equals(packageUri1),
      );

      await resolvedUriManager.fetchPackageUris(isolateId, [uri2]);
      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri1),
        equals(packageUri1),
      );
      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri2),
        equals(packageUri2),
      );
    });

    test('caches different mappings between different isolates', () async {
      const String isolateId2 = 'anIsolateId2';
      const String packageUriFromDifferentIsolate =
          'this/is/a/third/packageUri3';
      when(serviceManager.service!.lookupPackageUris(isolateId, [uri1]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );
      when(serviceManager.service!.lookupPackageUris(isolateId2, [uri1]))
          .thenAnswer(
        (realInvocation) =>
            Future.value(UriList(uris: [packageUriFromDifferentIsolate])),
      );

      await resolvedUriManager.fetchPackageUris(isolateId, [uri1]);
      await resolvedUriManager.fetchPackageUris(isolateId2, [uri1]);

      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri1),
        equals(packageUri1),
      );
      expect(
        resolvedUriManager.lookupPackageUri(isolateId2, uri1),
        equals(packageUriFromDifferentIsolate),
      );
    });
  });
}
