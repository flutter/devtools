// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:convert';

import 'package:devtools_app/src/screens/network/network_controller.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/version.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'test_data/network_test_data.dart';
import 'test_utils/network_test_utils.dart';

void main() {
  group('NetworkRequest', () {
    test('method returns correct value', () {
      expect(httpGetEvent.method, equals('GET'));
      expect(httpPutEvent.method, equals('PUT'));
      expect(httpGetEventWithError.method, equals('GET'));
      expect(httpInvalidEvent.method, isNull);
      expect(httpInProgressEvent.method, equals('GET'));

      expect(testSocket1.method, equals('GET'));
      expect(testSocket2.method, equals('GET'));
    });

    test('uri returns correct value', () {
      expect(httpGetEvent.uri,
          equals('http://127.0.0.1:8011/foo/bar?foo=bar&year=2019'));
      expect(httpPutEvent.uri, equals('http://127.0.0.1:8011/foo/bar'));
      expect(httpGetEventWithError.uri, equals('http://www.example.com/'));
      expect(httpInvalidEvent.uri, isNull);
      expect(httpInProgressEvent.uri,
          equals('http://127.0.0.1:8011/foo/bar?foo=bar&year=2019'));

      expect(testSocket1.uri,
          equals('InternetAddress(\'2606:4700:3037::ac43:bd8f\', IPv6)'));
      expect(testSocket2.uri,
          equals('InternetAddress(\'2606:4700:3037::ac43:0000\', IPv6)'));
    });

    test('contentType returns correct value', () {
      expect(httpGetEvent.contentType, equals('[text/plain; charset=utf-8]'));
      expect(httpPutEvent.contentType,
          equals('[application/json; charset=utf-8]'));
      expect(httpGetEventWithError.contentType, isNull);
      expect(httpInProgressEvent.contentType, isNull);
      expect(httpInvalidEvent.contentType, isNull);

      expect(testSocket1.contentType, equals('websocket'));
      expect(testSocket2.contentType, equals('websocket'));
    });

    test('type returns correct value', () {
      expect(httpGetEvent.type, equals('txt'));
      expect(httpPutEvent.type, equals('json'));
      expect(httpGetEventWithError.type, equals('http'));
      expect(httpInvalidEvent.type, equals('http'));
      expect(httpInProgressEvent.type, equals('http'));

      expect(testSocket1.type, equals('ws'));
      expect(testSocket2.type, equals('ws'));
    });

    test('duration returns correct value', () {
      expect(httpGetEvent.duration.inMicroseconds, equals(900000));
      expect(httpPutEvent.duration.inMicroseconds, equals(900000));
      expect(httpGetEventWithError.duration.inMicroseconds, equals(100000));
      expect(httpInvalidEvent.duration, isNull);
      expect(httpInProgressEvent.duration, isNull);

      expect(testSocket1.duration.inMicroseconds, equals(1000000));
      expect(testSocket2.duration, isNull);
    });

    test('startTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(formatDateTime(httpGetEvent.startTimestamp.toUtc()),
          equals('8:51:09.000'));
      expect(
        formatDateTime(httpPutEvent.startTimestamp.toUtc()),
        equals('8:51:11.000'),
      );
      expect(
        formatDateTime(httpGetEventWithError.startTimestamp.toUtc()),
        equals('8:51:13.000'),
      );
      expect(httpInvalidEvent.startTimestamp, isNull);
      expect(
        formatDateTime(httpInProgressEvent.startTimestamp.toUtc()),
        equals('8:51:17.000'),
      );

      expect(
        formatDateTime(testSocket1.startTimestamp.toUtc()),
        equals('0:00:01.000'),
      );
      expect(
        formatDateTime(testSocket2.startTimestamp.toUtc()),
        equals('0:00:03.000'),
      );
    });

    test('endTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(httpGetEvent.endTimestamp.toUtc()),
        equals('8:51:09.900'),
      );
      expect(
        formatDateTime(httpPutEvent.endTimestamp.toUtc()),
        equals('8:51:11.900'),
      );
      expect(
        formatDateTime(httpGetEventWithError.endTimestamp.toUtc()),
        equals('8:51:13.100'),
      );
      expect(httpInvalidEvent.endTimestamp, isNull);
      expect(httpInProgressEvent.endTimestamp, isNull);

      expect(
        formatDateTime(testSocket1.endTimestamp.toUtc()),
        equals('0:00:02.000'),
      );
      expect(testSocket2.endTimestamp, isNull);
    });

    test('status returns correct value', () {
      expect(httpGetEvent.status, equals('200'));
      expect(httpPutEvent.status, equals('200'));
      expect(httpGetEventWithError.status, equals('Error'));
      expect(httpInvalidEvent.status, isNull);
      expect(httpInProgressEvent.status, isNull);
      expect(testSocket1.status, equals('101'));
      expect(testSocket2.status, equals('101'));
    });

    test('port returns correct value', () {
      expect(httpGetEvent.port, equals(35248));
      expect(httpPutEvent.port, equals(35246));
      expect(httpGetEventWithError.port, isNull);
      expect(httpInvalidEvent.port, isNull);
      expect(httpInProgressEvent.port, isNull);
      expect(testSocket1.port, equals(443));
      expect(testSocket2.port, 80);
    });

    test('durationDisplay returns correct value', () {
      expect(httpGetEvent.durationDisplay, equals('Duration: 900.0 ms'));
      expect(httpPutEvent.durationDisplay, equals('Duration: 900.0 ms'));
      expect(httpGetEventWithError.durationDisplay, 'Duration: 100.0 ms');
      expect(httpInvalidEvent.durationDisplay, equals('Duration: Pending'));
      expect(httpInProgressEvent.durationDisplay, equals('Duration: Pending'));
      expect(testSocket1.durationDisplay, equals('Duration: 1000.0 ms'));
      expect(testSocket2.durationDisplay, equals('Duration: Pending'));
    });
  });

  group('HttpRequestData', () {
    test('isValid returns correct value', () {
      expect(httpGetEvent.isValid, isTrue);
      expect(httpPutEvent.isValid, isTrue);
      expect(httpGetEventWithError.isValid, isTrue);
      expect(httpInvalidEvent.isValid, isFalse);
      expect(httpInProgressEvent.isValid, isTrue);
    });

    test('general returns correct value', () {
      expect(
        collectionEquals(httpGetEvent.general, {
          'method': 'GET',
          'uri': 'http://127.0.0.1:8011/foo/bar?foo=bar&year=2019',
          'isolateId': 'isolates/3907117677703047',
          'compressionState':
              'HttpClientResponseCompressionState.notCompressed',
          'connectionInfo': {
            'localPort': 35248,
            'remoteAddress': '127.0.0.1',
            'remotePort': 8011
          },
          'contentLength': 0,
          'cookies': [],
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'redirects': [],
          'statusCode': 200,
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPutEvent.general, {
          'method': 'PUT',
          'uri': 'http://127.0.0.1:8011/foo/bar',
          'isolateId': 'isolates/3907117677703047',
          'compressionState':
              'HttpClientResponseCompressionState.notCompressed',
          'connectionInfo': {
            'localPort': 35246,
            'remoteAddress': '127.0.0.1',
            'remotePort': 8011
          },
          'contentLength': 0,
          'cookies': ['Cookie-Monster=Me-want-cookie!; HttpOnly'],
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'redirects': [],
          'statusCode': 200,
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpGetEventWithError.general, {
          'method': 'GET',
          'uri': 'http://www.example.com/',
          'isolateId': 'isolates/3494935576149295',
          'isolateGroupId': 'isolateGroups/12160347548294753697',
          'error':
              'SocketException: Failed host lookup: \'www.example.com\' (OS Error: nodename nor servname provided, or not known, errno = 8)',
        }),
        isTrue,
      );
      expect(httpInvalidEvent.general, isNull);
      expect(
        collectionEquals(httpInProgressEvent.general, {
          'method': 'GET',
          'uri': 'http://127.0.0.1:8011/foo/bar?foo=bar&year=2019',
          'isolateId': 'isolates/3907117677703047'
        }),
        isTrue,
      );
    });

    test('inProgress returns correct value', () {
      expect(httpGetEvent.inProgress, isFalse);
      expect(httpPutEvent.inProgress, isFalse);
      expect(httpGetEventWithError.inProgress, isFalse);
      expect(httpInvalidEvent.inProgress, isFalse);
      expect(httpInProgressEvent.inProgress, isTrue);
    });

    test('requestHeaders returns correct value', () {
      expect(
        collectionEquals(httpGetEvent.requestHeaders, {
          'user-agent': ['Dart/2.8 (dart:io)'],
          'accept-encoding': ['gzip'],
          'content-length': ['0'],
          'host': ['127.0.0.1:8011']
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPutEvent.requestHeaders, {
          'user-agent': ['Dart/2.8 (dart:io)'],
          'accept-encoding': ['gzip'],
          'content-length': ['0'],
          'host': ['127.0.0.1:8011']
        }),
        isTrue,
      );
      expect(httpGetEventWithError.requestHeaders, isNull);
      expect(httpInvalidEvent.requestHeaders, isNull);
      expect(httpInProgressEvent.requestHeaders, isNull);
    });

    test('responseHeaders returns correct value', () {
      expect(
        collectionEquals(httpGetEvent.responseHeaders, {
          'x-frame-options': ['SAMEORIGIN'],
          'content-type': ['text/plain; charset=utf-8'],
          'x-xss-protection': ['1; mode=block'],
          'x-content-type-options': ['nosniff'],
          'content-length': ['0']
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPutEvent.responseHeaders, {
          'x-frame-options': ['SAMEORIGIN'],
          'content-type': ['application/json; charset=utf-8'],
          'x-xss-protection': ['1; mode=block'],
          'set-cookie': ['Cookie-Monster=Me-want-cookie!; HttpOnly'],
          'x-content-type-options': ['nosniff'],
          'content-length': ['0']
        }),
        isTrue,
      );
      expect(httpGetEventWithError.responseHeaders, isNull);
      expect(httpInvalidEvent.responseHeaders, isNull);
      expect(httpInProgressEvent.responseHeaders, isNull);
    });

    test('requestCookies returns correct value', () {
      expect(httpGetEvent.requestCookies, isEmpty);
      expect(httpPutEvent.requestCookies, isEmpty);
      expect(httpGetEventWithError.requestCookies, isEmpty);
      expect(httpInvalidEvent.requestCookies, isEmpty);
      expect(httpInProgressEvent.requestCookies, isEmpty);
    });

    test('responseCookies returns correct value', () {
      expect(httpGetEvent.responseCookies, isEmpty);
      expect(httpPutEvent.responseCookies.first.toString(),
          equals('Cookie-Monster=Me-want-cookie!; HttpOnly'));
      expect(httpGetEventWithError.responseCookies, isEmpty);
      expect(httpInvalidEvent.responseCookies, isEmpty);
      expect(httpInProgressEvent.responseCookies, isEmpty);
    });

    test('hasCookies returns correct value', () {
      expect(httpGetEvent.hasCookies, isFalse);
      expect(httpPutEvent.hasCookies, isTrue);
      expect(httpGetEventWithError.hasCookies, isFalse);
      expect(httpInvalidEvent.hasCookies, isFalse);
      expect(httpInProgressEvent.hasCookies, isFalse);
    });

    test('responseBody returns correct value', () {
      expect(httpGetEvent.responseBody, isNotNull);
      expect(httpGetEvent.responseBody,
          equals(utf8.decode(httpGetResponseBodyData)));
      expect(httpPutEvent.responseBody, isNull);
      expect(httpGetEventWithError.responseBody, isNull);
      expect(httpInProgressEvent.responseBody, isNull);
      expect(httpInvalidEvent.responseBody, isNull);
    });
  });

  group('WebSocket', () {
    test('id returns correct value', () {
      expect(testSocket1.id, equals(0));
      expect(testSocket2.id, equals(1));
    });

    test('lastReadTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(testSocket1.lastReadTimestamp.toUtc()),
        equals('0:00:01.800'),
      );
      expect(
        formatDateTime(testSocket2.lastReadTimestamp.toUtc()),
        equals('0:00:03.500'),
      );
    });

    test('lastWriteTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(testSocket1.lastWriteTimestamp.toUtc()),
        equals('0:00:01.850'),
      );
      expect(
        formatDateTime(testSocket2.lastWriteTimestamp.toUtc()),
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
      expect(testSocket1.hashCode, equals(0));
      expect(testSocket2.hashCode, equals(1));
      expect(testSocket1 == testSocket2, isFalse);
      expect(testSocket1 == testSocket3, isTrue);
    });
  });

  group('DartIOHttpRequestData', () {
    NetworkController controller;
    FakeServiceManager fakeServiceManager;
    SocketProfile socketProfile;
    HttpProfile httpProfile;

    setUp(() async {
      socketProfile = loadSocketProfile();
      httpProfile = loadHttpProfile();
      // DartIOHttpRequestData.getFullRequestData relies on a call to serviceManager to
      // retrieve request details.
      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          socketProfile: socketProfile,
          httpProfile: httpProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      // Enables getHttpProfile support.
      final fakeVmService = fakeServiceManager.service as FakeVmService;
      fakeVmService.dartIoVersion = SemanticVersion(major: 1, minor: 6);
      fakeVmService.httpEnableTimelineLoggingResult = false;
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
      expect(httpGet.duration.inMicroseconds, 6327091628 - 6326279935);
      expect(httpGetWithError.duration.inMicroseconds, 5387256813 - 5385227316);
      expect(httpPost.duration.inMicroseconds, 2401000670 - 2399492629);
      expect(httpPut.duration.inMicroseconds, 1206609144 - 1205283313);
      expect(httpPatch.duration.inMicroseconds, 1911420918 - 1910177192);
      expect(httpWsHandshake.duration.inMicroseconds, 8140263470 - 8140222102);
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
        formatDateTime(httpGet.endTimestamp.toUtc()),
        '1:45:27.091',
      );
      expect(
        formatDateTime(httpGetWithError.endTimestamp.toUtc()),
        '1:29:47.256',
      );
      expect(
        formatDateTime(httpPost.endTimestamp.toUtc()),
        '0:40:01.000',
      );
      expect(
        formatDateTime(httpPut.endTimestamp.toUtc()),
        '0:20:06.609',
      );
      expect(
        formatDateTime(httpPatch.endTimestamp.toUtc()),
        '0:31:51.420',
      );
      expect(
        formatDateTime(httpWsHandshake.endTimestamp.toUtc()),
        '2:15:40.263',
      );
    });

    test('status returns correct value', () {
      expect(httpGet.status, '200');
      expect(httpGetEventWithError.status, 'Error');
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
          'redirects': [],
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
          'redirects': [],
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
          'redirects': [],
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
          'redirects': [],
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
          'redirects': [],
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
          'transfer-encoding': [],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPut.requestHeaders, {
          'transfer-encoding': [],
        }),
        isTrue,
      );
      expect(
        collectionEquals(httpPatch.requestHeaders, {
          'transfer-encoding': [],
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
