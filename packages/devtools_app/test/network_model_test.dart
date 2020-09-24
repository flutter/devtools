// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/utils.dart';
import 'package:test/test.dart';

import 'support/network_test_data.dart';

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
      expect(httpGetEvent.type, equals('conf'));
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
          equals('8:51:09.000 AM'));
      expect(
        formatDateTime(httpPutEvent.startTimestamp.toUtc()),
        equals('8:51:11.000 AM'),
      );
      expect(
        formatDateTime(httpGetEventWithError.startTimestamp.toUtc()),
        equals('8:51:13.000 AM'),
      );
      expect(httpInvalidEvent.startTimestamp, isNull);
      expect(
        formatDateTime(httpInProgressEvent.startTimestamp.toUtc()),
        equals('8:51:17.000 AM'),
      );

      expect(
        formatDateTime(testSocket1.startTimestamp.toUtc()),
        equals('12:00:01.000 AM'),
      );
      expect(
        formatDateTime(testSocket2.startTimestamp.toUtc()),
        equals('12:00:03.000 AM'),
      );
    });

    test('endTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(httpGetEvent.endTimestamp.toUtc()),
        equals('8:51:09.900 AM'),
      );
      expect(
        formatDateTime(httpPutEvent.endTimestamp.toUtc()),
        equals('8:51:11.900 AM'),
      );
      expect(
        formatDateTime(httpGetEventWithError.endTimestamp.toUtc()),
        equals('8:51:13.100 AM'),
      );
      expect(httpInvalidEvent.endTimestamp, isNull);
      expect(httpInProgressEvent.endTimestamp, isNull);

      expect(
        formatDateTime(testSocket1.endTimestamp.toUtc()),
        equals('12:00:02.000 AM'),
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
        equals('12:00:01.800 AM'),
      );
      expect(
        formatDateTime(testSocket2.lastReadTimestamp.toUtc()),
        equals('12:00:03.500 AM'),
      );
    });

    test('lastWriteTimestamp returns correct value', () {
      // Test these values in UTC to avoid timezone differences with the bots.
      expect(
        formatDateTime(testSocket1.lastWriteTimestamp.toUtc()),
        equals('12:00:01.850 AM'),
      );
      expect(
        formatDateTime(testSocket2.lastWriteTimestamp.toUtc()),
        equals('12:00:03.600 AM'),
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
}
