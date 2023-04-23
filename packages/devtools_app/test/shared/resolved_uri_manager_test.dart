// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/service/resolved_uri_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  late ResolvedUriManager resolvedUriManager;
  final service = createMockVmServiceWrapperWithDefaults();

  setGlobal(ServiceConnectionManager, FakeServiceManager(service: service));
  resolvedUriManager = ResolvedUriManager();

  const String isolateId = 'anIsolateId';
  const uri1 = 'this/is/a/uri1';
  const uri2 = 'this/is/a/uri2';
  const packageUri1 = 'uri/am/i1';
  const packageUri2 = 'uri/am/i2';

  group('lifecycle', () {
    setUp(() {
      when(
        unawaited(
          serviceManager.service!.lookupPackageUris(isolateId, [uri1]),
        ),
      ).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );
    });

    test('does nothing before vmServiceOpened', () async {
      await resolvedUriManager.fetchPackageUris(isolateId, [uri1]);
      await resolvedUriManager.fetchFileUris(isolateId, [packageUri1]);

      expect(resolvedUriManager.lookupPackageUri(isolateId, uri1), isNull);
      expect(resolvedUriManager.lookupFileUri(isolateId, packageUri1), isNull);
      verifyNever(service.lookupPackageUris(isolateId, any));
      verifyNever(service.lookupResolvedPackageUris(isolateId, any));
    });

    test('does nothing after vmServiceClosed', () async {
      resolvedUriManager.vmServiceOpened();
      resolvedUriManager.vmServiceClosed();

      await resolvedUriManager.fetchPackageUris(isolateId, [uri1]);
      await resolvedUriManager.fetchFileUris(isolateId, [packageUri1]);

      expect(resolvedUriManager.lookupPackageUri(isolateId, uri1), isNull);
      expect(resolvedUriManager.lookupFileUri(isolateId, packageUri1), isNull);
      verifyNever(service.lookupPackageUris(isolateId, any));
      verifyNever(service.lookupResolvedPackageUris(isolateId, any));
    });
  });

  group('file to package mappings', () {
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

    test('preserves the reverse package to file mapping', () async {
      when(
        serviceManager.service!.lookupPackageUris(
          isolateId,
          [uri1],
        ),
      ).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );

      await resolvedUriManager.fetchPackageUris(isolateId, [uri1]);

      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri1),
        equals(packageUri1),
      );
      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri1),
        equals(uri1),
      );
    });
  });

  group('package to file mappings', () {
    setUp(() {
      resolvedUriManager.vmServiceOpened();
    });

    test('lookupFileUri when package is unknown', () {
      final fileUriResult =
          resolvedUriManager.lookupFileUri(isolateId, 'package:some/uri');
      expect(fileUriResult, isNull);
    });

    test('lookupFileUri', () async {
      when(
        serviceManager.service!.lookupResolvedPackageUris(
          isolateId,
          [packageUri1, packageUri2],
        ),
      ).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [uri1, uri2])),
      );

      await resolvedUriManager
          .fetchFileUris(isolateId, [packageUri1, packageUri2]);

      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri1),
        equals(uri1),
      );
      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri2),
        equals(uri2),
      );
    });

    test('remembers already fetched file paths', () async {
      when(
        serviceManager.service!
            .lookupResolvedPackageUris(isolateId, [packageUri1]),
      ).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [uri1])),
      );
      when(
        serviceManager.service!
            .lookupResolvedPackageUris(isolateId, [packageUri2]),
      ).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [uri2])),
      );

      await resolvedUriManager.fetchFileUris(isolateId, [packageUri1]);
      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri1),
        equals(uri1),
      );

      await resolvedUriManager.fetchFileUris(isolateId, [packageUri2]);
      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri1),
        equals(uri1),
      );
      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri2),
        equals(uri2),
      );
    });

    test('caches different mappings between different isolates', () async {
      const String isolateId2 = 'anIsolateId2';
      const String fileUriFromDifferentIsolate =
          'file:///this/is/a/third/fileUri3';
      when(
        serviceManager.service!
            .lookupResolvedPackageUris(isolateId, [packageUri1]),
      ).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [uri1])),
      );
      when(
        serviceManager.service!
            .lookupResolvedPackageUris(isolateId2, [packageUri1]),
      ).thenAnswer(
        (realInvocation) =>
            Future.value(UriList(uris: [fileUriFromDifferentIsolate])),
      );

      await resolvedUriManager.fetchFileUris(isolateId, [packageUri1]);
      await resolvedUriManager.fetchFileUris(isolateId2, [packageUri1]);

      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri1),
        equals(uri1),
      );
      expect(
        resolvedUriManager.lookupFileUri(isolateId2, packageUri1),
        equals(fileUriFromDifferentIsolate),
      );
    });

    test('preserves the reverse file to package mapping', () async {
      when(
        serviceManager.service!.lookupResolvedPackageUris(
          isolateId,
          [packageUri1],
        ),
      ).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [uri1])),
      );

      await resolvedUriManager.fetchFileUris(isolateId, [packageUri1]);

      expect(
        resolvedUriManager.lookupFileUri(isolateId, packageUri1),
        equals(uri1),
      );
      expect(
        resolvedUriManager.lookupPackageUri(isolateId, uri1),
        equals(packageUri1),
      );
    });
  });
}
