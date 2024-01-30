// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/screens/network/network_controller.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/network.dart';
import 'utils/network_test_utils.dart';

void main() {
  group('WebSocket', () {
    test('id returns correct value', () {
      expect(testSocket1.id, equals('10000'));
      expect(testSocket2.id, equals('11111'));
    });

    test('lastReadTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(testSocket1.lastReadTimestamp!.toUtc()),
        equals('0:00:01.800'),
      );
      expect(
        formatDateTime(testSocket2.lastReadTimestamp!.toUtc()),
        equals('0:00:03.500'),
      );
    });

    test('lastWriteTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(testSocket1.lastWriteTimestamp!.toUtc()),
        equals('0:00:01.850'),
      );
      expect(
        formatDateTime(testSocket2.lastWriteTimestamp!.toUtc()),
        equals('0:00:03.600'),
      );
    });

    test('socketType returns correct value', () {
      expect(testSocket1.socketType, equals('tcp'));
      expect(testSocket2.socketType, equals('tcp'));
    });

    test('readBytes returns correct value', () {
      expect(testSocket1.readBytes, equals(10));
      expect(testSocket2.readBytes, equals(20));
    });

    test('writeBytes returns correct value', () {
      expect(testSocket1.writeBytes, equals(15));
      expect(testSocket2.writeBytes, equals(25));
    });

    test('equals and hash return the correct value', () {
      expect(testSocket1.hashCode, equals('10000'.hashCode));
      expect(testSocket2.hashCode, equals('11111'.hashCode));
      expect(testSocket1 == testSocket2, isFalse);
      expect(testSocket1 == testSocket3, isTrue);
    });
  });

  group('DartIOHttpRequestData', () {
    NetworkController controller;
    FakeServiceConnectionManager fakeServiceConnection;
    SocketProfile socketProfile;
    HttpProfile httpProfile;

    setUp(() async {
      socketProfile = loadSocketProfile();
      httpProfile = loadHttpProfile();
      // DartIOHttpRequestData.getFullRequestData relies on a call to serviceManager to
      // retrieve request details.
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          socketProfile: socketProfile,
          httpProfile: httpProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      controller = NetworkController();
      await controller.startRecording();
    });

    test('method returns correct value', () {
      expect(httpGet.method, 'GET');
      expect(httpGetWithError.method, 'GET');
      expect(httpPost.method, 'POST');
      expect(httpPut.method, 'PUT');
      expect(httpPatch.method, 'PATCH');
      expect(httpWsHandshake.method, equals('GET'));
    });

    test('uri returns correct value', () {
      expect(httpGet.uri, 'https://jsonplaceholder.typicode.com/albums/1');
      expect(httpGetWithError.uri, 'https://www.examplez.com/1');
      expect(httpPost.uri, 'https://jsonplaceholder.typicode.com/posts');
      expect(httpPut.uri, 'https://jsonplaceholder.typicode.com/posts/1');
      expect(httpPatch.uri, 'https://jsonplaceholder.typicode.com/posts/1');
      expect(httpWsHandshake.uri, 'http://localhost:8080');
    });

    test('contentType returns correct value', () {
      expect(httpGet.contentType, '[application/json; charset=utf-8]');
      expect(httpGetWithError.contentType, isNull);
      expect(httpPost.contentType, '[application/json; charset=utf-8]');
      expect(httpPut.contentType, '[application/json; charset=utf-8]');
      expect(httpPatch.contentType, '[application/json; charset=utf-8]');
      expect(httpWsHandshake.contentType, isNull);
    });

    test('type returns correct value', () {
      expect(httpGet.type, 'json');
      expect(httpGetWithError.type, 'http');
      expect(httpPost.type, 'json');
      expect(httpPut.type, 'json');
      expect(httpPatch.type, 'json');
      expect(httpWsHandshake.type, 'http');
    });

    test('duration returns correct value', () {
      expect(httpGet.duration!.inMicroseconds, 6327091628 - 6326279935);
      expect(
        httpGetWithError.duration!.inMicroseconds,
        5387256813 - 5385227316,
      );
      expect(httpPost.duration!.inMicroseconds, 2401000670 - 2399492629);
      expect(httpPut.duration!.inMicroseconds, 1206609144 - 1205283313);
      expect(httpPatch.duration!.inMicroseconds, 1911420918 - 1910177192);
      expect(httpWsHandshake.duration!.inMicroseconds, 8140263470 - 8140222102);
    });

    test('startTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(httpGet.startTimestamp.toUtc()),
        '1:45:26.279',
      );
      expect(
        formatDateTime(httpGetWithError.startTimestamp.toUtc()),
        '1:29:45.227',
      );
      expect(
        formatDateTime(httpPost.startTimestamp.toUtc()),
        '0:39:59.492',
      );
      expect(
        formatDateTime(httpPut.startTimestamp.toUtc()),
        '0:20:05.283',
      );
      expect(
        formatDateTime(httpPatch.startTimestamp.toUtc()),
        '0:31:50.177',
      );
      expect(
        formatDateTime(httpWsHandshake.startTimestamp.toUtc()),
        '2:15:40.222',
      );
    });

    test('endTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(httpGet.endTimestamp!.toUtc()),
        '1:45:27.091',
      );
      expect(
        formatDateTime(httpGetWithError.endTimestamp!.toUtc()),
        '1:29:47.256',
      );
      expect(
        formatDateTime(httpPost.endTimestamp!.toUtc()),
        '0:40:01.000',
      );
      expect(
        formatDateTime(httpPut.endTimestamp!.toUtc()),
        '0:20:06.609',
      );
      expect(
        formatDateTime(httpPatch.endTimestamp!.toUtc()),
        '0:31:51.420',
      );
      expect(
        formatDateTime(httpWsHandshake.endTimestamp!.toUtc()),
        '2:15:40.263',
      );
    });

    test('status returns correct value', () {
      expect(httpGet.status, '200');
      expect(httpGetWithError.status, 'Error');
      expect(httpPost.status, '201');
      expect(httpPut.status, '200');
      expect(httpPatch.status, '200');
      expect(httpWsHandshake.status, '101');
    });

    test('port returns correct value', () {
      expect(httpGet.port, 45648);
      expect(httpGetWithError.port, isNull);
      expect(httpPost.port, 55972);
      expect(httpPut.port, 43684);
      expect(httpPatch.port, 43864);
      expect(httpWsHandshake.port, 56744);
    });

    test('durationDisplay returns correct value', () {
      expect(httpGet.durationDisplay, 'Duration: 811.7 ms');
      expect(httpGetWithError.durationDisplay, 'Duration: 2029.5 ms');
      expect(httpPost.durationDisplay, 'Duration: 1508.0 ms');
      expect(httpPut.durationDisplay, 'Duration: 1325.8 ms');
      expect(httpPatch.durationDisplay, 'Duration: 1243.7 ms');
      expect(httpWsHandshake.durationDisplay, 'Duration: 41.4 ms');
    });

    test('isValid returns correct value', () {
      expect(httpGet.isValid, isTrue);
      expect(httpGetWithError.isValid, isTrue);
      expect(httpPost.isValid, isTrue);
      expect(httpPut.isValid, isTrue);
      expect(httpPatch.isValid, isTrue);
      expect(httpWsHandshake.isValid, isTrue);
    });

    test('general returns correct value', () {
      expect(
        collectionEquals(httpGet.general, {
          'method': 'GET',
          'uri': 'https://jsonplaceholder.typicode.com/albums/1',
          'connectionInfo': {
            'localPort': 45648,
            'remoteAddress': '2606:4700:3033::ac43:bdd9',
            'remotePort': 443,
          },
          'contentLength': 0,
          'compressionState': 'HttpClientResponseCompressionState.decompressed',
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'redirects': <Object?>[],
          'statusCode': 200,
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpGetWithError.general, {
          'method': 'GET',
          'uri': 'https://www.examplez.com/1',
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPost.general, {
          'method': 'POST',
          'uri': 'https://jsonplaceholder.typicode.com/posts',
          'connectionInfo': {
            'localPort': 55972,
            'remoteAddress': '2606:4700:3033::ac43:bdd9',
            'remotePort': 443,
          },
          'contentLength': -1,
          'compressionState':
              'HttpClientResponseCompressionState.notCompressed',
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'Created',
          'redirects': <Object?>[],
          'statusCode': 201,
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPut.general, {
          'method': 'PUT',
          'uri': 'https://jsonplaceholder.typicode.com/posts/1',
          'connectionInfo': {
            'localPort': 43684,
            'remoteAddress': '2606:4700:3033::ac43:bdd9',
            'remotePort': 443,
          },
          'contentLength': -1,
          'compressionState':
              'HttpClientResponseCompressionState.notCompressed',
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'redirects': <Object?>[],
          'statusCode': 200,
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPatch.general, {
          'method': 'PATCH',
          'uri': 'https://jsonplaceholder.typicode.com/posts/1',
          'connectionInfo': {
            'localPort': 43864,
            'remoteAddress': '2606:4700:3033::ac43:bdd9',
            'remotePort': 443,
          },
          'contentLength': -1,
          'compressionState': 'HttpClientResponseCompressionState.decompressed',
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'redirects': <Object?>[],
          'statusCode': 200,
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpWsHandshake.general, {
          'method': 'GET',
          'uri': 'http://localhost:8080',
          'connectionInfo': {
            'localPort': 56744,
            'remoteAddress': '127.0.0.1',
            'remotePort': 8080,
          },
          'contentLength': 0,
          'compressionState':
              'HttpClientResponseCompressionState.notCompressed',
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'Switching Protocols',
          'redirects': <Object?>[],
          'statusCode': 101,
        }),
        isTrue,
      );
    });

    test('inProgress returns correct value', () {
      expect(httpGet.inProgress, false);
      expect(httpGetWithError.inProgress, false);
      expect(httpPost.inProgress, false);
      expect(httpPut.inProgress, false);
      expect(httpPatch.inProgress, false);
      expect(httpWsHandshake.inProgress, false);
    });

    test('requestHeaders returns correct value', () {
      expect(
        collectionEquals(httpGet.requestHeaders, {
          'content-length': ['0'],
        }),
        isTrue,
      );
      expect(httpGetWithError.requestHeaders, isNull);
      expect(
        collectionEquals(httpPost.requestHeaders, {
          'transfer-encoding': <Object?>[],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPut.requestHeaders, {
          'transfer-encoding': <Object?>[],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPatch.requestHeaders, {
          'transfer-encoding': <Object?>[],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpWsHandshake.requestHeaders, {
          'content-length': ['0'],
        }),
        isTrue,
      );
    });

    test('responseHeaders returns correct value', () {
      expect(
        collectionEquals(httpGet.responseHeaders, {
          'content-encoding': ['gzip'],
          'pragma': ['no-cache'],
          'connection': ['keep-alive'],
          'cache-control': ['max-age=43200'],
          'content-type': ['application/json; charset=utf-8'],
        }),
        isTrue,
      );
      expect(httpGetWithError.responseHeaders, isNull);
      expect(
        collectionEquals(httpPost.responseHeaders, {
          'date': ['Wed, 04 Aug 2021 07:57:26 GMT'],
          'location': ['http://jsonplaceholder.typicode.com/posts/101'],
          'content-length': [15],
          'connection': ['keep-alive'],
          'cache-control': ['no-cache'],
          'content-type': ['application/json; charset=utf-8'],
          'x-powered-by': ['Express'],
          'expires': [-1],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPut.responseHeaders, {
          'connection': ['keep-alive'],
          'cache-control': ['no-cache'],
          'date': ['Wed, 04 Aug 2021 08:57:24 GMT'],
          'content-type': ['application/json; charset=utf-8'],
          'pragma': ['no-cache'],
          'access-control-allow-credentials': [true],
          'content-length': [13],
          'expires': [-1],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPatch.responseHeaders, {
          'connection': ['keep-alive'],
          'cache-control': ['no-cache'],
          'transfer-encoding': ['chunked'],
          'date': ['Wed, 04 Aug 2021 09:09:09 GMT'],
          'content-encoding': ['gzip'],
          'content-type': ['application/json; charset=utf-8'],
          'pragma': ['no-cache'],
          'expires': [-1],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpWsHandshake.responseHeaders, {
          'connection': ['Upgrade'],
          'upgrade': ['websocket'],
          'content-length': [0],
          'sec-websocket-version': [13],
          'sec-websocket-accept': ['JF5SBCGrfyYAoLKzvj6A0ZVpk6c='],
        }),
        isTrue,
      );
    });

    test('requestCookies returns correct value', () {
      expect(httpGet.requestCookies, isEmpty);
      expect(httpGetWithError.requestCookies, isEmpty);
      expect(httpPost.requestCookies, isEmpty);
      expect(httpPut.requestCookies, isEmpty);
      expect(httpPatch.requestCookies, isEmpty);
      expect(httpWsHandshake.requestCookies, isEmpty);
    });

    test('responseCookies returns correct value', () {
      expect(httpGet.responseCookies, isEmpty);
      expect(httpGetWithError.responseCookies, isEmpty);
      expect(httpPost.responseCookies, isEmpty);
      expect(httpPut.responseCookies, isEmpty);
      expect(httpPatch.responseCookies, isEmpty);
      expect(httpWsHandshake.responseCookies, isEmpty);
    });

    test('hasCookies returns correct value', () {
      expect(httpGet.hasCookies, isFalse);
      expect(httpGetWithError.hasCookies, isFalse);
      expect(httpPost.hasCookies, isFalse);
      expect(httpPut.hasCookies, isFalse);
      expect(httpPatch.hasCookies, isFalse);
      expect(httpWsHandshake.hasCookies, isFalse);
    });

    test('requestBody returns correct value', () {
      expect(httpGet.requestBody, isNull);
      expect(httpGetWithError.requestBody, isNull);
      expect(httpPost.requestBody, utf8.decode(httpPostRequestBodyData));
      expect(httpPut.requestBody, utf8.decode(httpPutRequestBodyData));
      expect(httpPatch.requestBody, utf8.decode(httpPatchRequestBodyData));
      expect(httpWsHandshake.requestBody, isNull);
    });

    test('responseBody returns correct value', () {
      expect(httpGet.responseBody, utf8.decode(httpGetResponseBodyData));
      expect(httpGetWithError.responseBody, isNull);
      expect(httpPost.responseBody, utf8.decode(httpPostResponseBodyData));
      expect(httpPut.responseBody, utf8.decode(httpPutResponseBodyData));
      expect(httpPatch.responseBody, utf8.decode(httpPatchResponseBodyData));
      expect(httpWsHandshake.responseBody, isEmpty);
    });

    test('didFail returns correct value', () {
      expect(httpGet.didFail, false);
      expect(httpGetWithError.didFail, true);
      expect(httpPost.didFail, false);
      expect(httpPut.didFail, false);
      expect(httpPatch.didFail, false);
      expect(httpWsHandshake.didFail, false);
    });
  });
}
