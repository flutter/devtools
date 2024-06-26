// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  late ResolvedUriManager resolvedUriManager;
  late MockVmServiceWrapper service;

  const isolateId = 'anIsolateId';
  const uri1 = 'this/is/a/uri1';
  const uri2 = 'this/is/a/uri2';
  const packageUri1 = 'uri/am/i1';
  const packageUri2 = 'uri/am/i2';

  setUp(() {
    service = createMockVmServiceWrapperWithDefaults();
    resolvedUriManager = ResolvedUriManager();
  });

  group('lifecycle', () {
    setUp(() {
      when(unawaited(service.lookupPackageUris(isolateId, [uri1]))).thenAnswer(
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
      resolvedUriManager.vmServiceOpened(service);
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
      resolvedUriManager.vmServiceOpened(service);
    });

    test('lookupPackageUri when uri is unknown', () {
      final packageUriResult =
          resolvedUriManager.lookupPackageUri(isolateId, 'some/uri');
      expect(packageUriResult, isNull);
    });

    test('lookupPackageUris', () async {
      when(service.lookupPackageUris(isolateId, [uri1, uri2])).thenAnswer(
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
      when(service.lookupPackageUris(isolateId, [uri1])).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );
      when(service.lookupPackageUris(isolateId, [uri2])).thenAnswer(
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
      const isolateId2 = 'anIsolateId2';
      const packageUriFromDifferentIsolate = 'this/is/a/third/packageUri3';
      when(service.lookupPackageUris(isolateId, [uri1])).thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [packageUri1])),
      );
      when(service.lookupPackageUris(isolateId2, [uri1])).thenAnswer(
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
      when(service.lookupPackageUris(isolateId, [uri1])).thenAnswer(
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
      resolvedUriManager.vmServiceOpened(service);
    });

    test('lookupFileUri when package is unknown', () {
      final fileUriResult =
          resolvedUriManager.lookupFileUri(isolateId, 'package:some/uri');
      expect(fileUriResult, isNull);
    });

    test('lookupFileUri', () async {
      when(
        service
            .lookupResolvedPackageUris(isolateId, [packageUri1, packageUri2]),
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
      when(service.lookupResolvedPackageUris(isolateId, [packageUri1]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [uri1])),
      );
      when(service.lookupResolvedPackageUris(isolateId, [packageUri2]))
          .thenAnswer(
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
      const isolateId2 = 'anIsolateId2';
      const fileUriFromDifferentIsolate = 'file:///this/is/a/third/fileUri3';
      when(service.lookupResolvedPackageUris(isolateId, [packageUri1]))
          .thenAnswer(
        (realInvocation) => Future.value(UriList(uris: [uri1])),
      );
      when(service.lookupResolvedPackageUris(isolateId2, [packageUri1]))
          .thenAnswer(
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
      when(service.lookupResolvedPackageUris(isolateId, [packageUri1]))
          .thenAnswer(
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
