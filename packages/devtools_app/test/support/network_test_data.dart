// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_model.dart';
import 'package:vm_service/vm_service.dart';

const _getStartTime = 231935000000;
final httpGetEvent = HttpRequestData.fromTimeline(
  timelineMicrosBase: _getStartTime - 1000000, // - 1000000 is arbitrary.
  requestEvents: httpGetEventTrace,
  responseEvents: httpGetResponseEventTrace,
);
final httpGetEventTrace = [
  {
    'name': 'HTTP CLIENT GET',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': _getStartTime,
    'ph': 'b',
    'id': '1d',
    'args': {
      'filterKey': 'HTTP/client',
      'method': 'GET',
      'uri': 'http://127.0.0.1:8011/foo/bar?foo=bar&year=2019',
      'isolateId': 'isolates/3907117677703047'
    }
  },
  {
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231935100000,
    'ph': 'n',
    'id': '1d',
    'args': {'isolateId': 'isolates/3907117677703047'}
  },
  {
    'name': 'Request initiated',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231935200000,
    'ph': 'n',
    'id': '1d',
    'args': {'isolateId': 'isolates/3907117677703047'}
  },
  {
    'name': 'Response received',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231935400000,
    'ph': 'n',
    'id': '1d',
    'args': {'isolateId': 'isolates/3907117677703047'}
  },
  {
    'name': 'HTTP CLIENT GET',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231935900000,
    'ph': 'e',
    'id': '1d',
    'args': {
      'requestHeaders': {
        'user-agent': ['Dart/2.8 (dart:io)'],
        'accept-encoding': ['gzip'],
        'content-length': ['0'],
        'host': ['127.0.0.1:8011']
      },
      'compressionState': 'HttpClientResponseCompressionState.notCompressed',
      'connectionInfo': {
        'localPort': 35248,
        'remoteAddress': '127.0.0.1',
        'remotePort': 8011
      },
      'contentLength': 0,
      'cookies': [],
      'responseHeaders': {
        'x-frame-options': ['SAMEORIGIN'],
        'content-type': ['text/plain; charset=utf-8'],
        'x-xss-protection': ['1; mode=block'],
        'x-content-type-options': ['nosniff'],
        'content-length': ['0']
      },
      'isRedirect': false,
      'persistentConnection': true,
      'reasonPhrase': 'OK',
      'redirects': [],
      'statusCode': 200,
      'isolateId': 'isolates/3907117677703047'
    }
  },
];

final httpGetResponseBodyData = [
  123,
  10,
  32,
  32,
  34,
  117,
  115,
  101,
  114,
  73,
  100,
  34,
  58,
  32,
  49,
  44,
  10,
  32,
  32,
  34,
  105,
  100,
  34,
  58,
  32,
  49,
  44,
  10,
  32,
  32,
  34,
  116,
  105,
  116,
  108,
  101,
  34,
  58,
  32,
  34,
  113,
  117,
  105,
  100,
  101,
  109,
  32,
  109,
  111,
  108,
  101,
  115,
  116,
  105,
  97,
  101,
  32,
  101,
  110,
  105,
  109,
  34,
  10,
  125
];

final httpGetResponseEventTrace = [
  {
    'name': 'HTTP CLIENT response of GET',
    'cat': 'Dart',
    'tid': 9018,
    'pid': 8985,
    'ts': 465424288688,
    'ph': 'b',
    'id': '1e',
    'args': {
      'requestUri': 'https://jsonplaceholder.typicode.com/albums/1',
      'statusCode': 200,
      'reasonPhrase': 'OK',
      'parentId': '1d',
      'filterKey': 'HTTP/client',
      'isolateId': 'isolates/1430600241264643',
      'isolateGroupId': 'isolateGroups/1765553891304005367'
    },
  },
  {
    'name': 'Response body',
    'cat': 'Dart',
    'tid': 9018,
    'pid': 8985,
    'ts': 465424289902,
    'ph': 'n',
    'id': '1e',
    'args': {
      'data': httpGetResponseBodyData,
      'filterKey': 'HTTP/client',
      'isolateId': 'isolates/1430600241264643',
      'isolateGroupId': 'isolateGroups/1765553891304005367'
    },
  },
  {
    'name': 'HTTP CLIENT response of GET',
    'cat': 'Dart',
    'tid': 9018,
    'pid': 8985,
    'ts': 465424291160,
    'ph': 'e',
    'id': '1e',
    'args': {
      'filterKey': 'HTTP/client',
      'isolateId': 'isolates/1430600241264643',
      'isolateGroupId': 'isolateGroups/1765553891304005367'
    },
  },
];

const _putStartTime = 231936000000;
final httpPutEvent = HttpRequestData.fromTimeline(
  timelineMicrosBase: _putStartTime - 1000000, // - 1000000 is arbitrary.
  requestEvents: httpPutEventTrace,
  responseEvents: [],
);
final httpPutEventTrace = [
  {
    'name': 'HTTP CLIENT PUT',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': _putStartTime,
    'ph': 'b',
    'id': '17',
    'args': {
      'filterKey': 'HTTP/client',
      'method': 'PUT',
      'uri': 'http://127.0.0.1:8011/foo/bar',
      'isolateId': 'isolates/3907117677703047'
    }
  },
  {
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231936300000,
    'ph': 'n',
    'id': '17',
    'args': {'isolateId': 'isolates/3907117677703047'}
  },
  {
    'name': 'Request initiated',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231936600000,
    'ph': 'n',
    'id': '17',
    'args': {'isolateId': 'isolates/3907117677703047'}
  },
  {
    'name': 'Response receieved',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231936800000,
    'ph': 'n',
    'id': '17',
    'args': {'isolateId': 'isolates/3907117677703047'}
  },
  {
    'name': 'HTTP CLIENT PUT',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231936900000,
    'ph': 'e',
    'id': '17',
    'args': {
      'requestHeaders': {
        'user-agent': ['Dart/2.8 (dart:io)'],
        'accept-encoding': ['gzip'],
        'content-length': ['0'],
        'host': ['127.0.0.1:8011']
      },
      'compressionState': 'HttpClientResponseCompressionState.notCompressed',
      'connectionInfo': {
        'localPort': 35246,
        'remoteAddress': '127.0.0.1',
        'remotePort': 8011
      },
      'contentLength': 0,
      'cookies': ['Cookie-Monster=Me-want-cookie!; HttpOnly'],
      'responseHeaders': {
        'x-frame-options': ['SAMEORIGIN'],
        'content-type': ['application/json; charset=utf-8'],
        'x-xss-protection': ['1; mode=block'],
        'set-cookie': ['Cookie-Monster=Me-want-cookie!; HttpOnly'],
        'x-content-type-options': ['nosniff'],
        'content-length': ['0']
      },
      'isRedirect': false,
      'persistentConnection': true,
      'reasonPhrase': 'OK',
      'redirects': [],
      'statusCode': 200,
      'isolateId': 'isolates/3907117677703047'
    }
  },
];

const _getWithErrorStartTime = 231937000000;
final httpGetEventWithError = HttpRequestData.fromTimeline(
  timelineMicrosBase:
      _getWithErrorStartTime - 1000000, // - 1000000 is arbitrary.
  requestEvents: httpGetEventWithErrorTrace,
  responseEvents: [],
);
final httpGetEventWithErrorTrace = [
  {
    'name': 'HTTP CLIENT GET',
    'cat': 'Dart',
    'tid': 21767,
    'pid': 81479,
    'ts': _getWithErrorStartTime,
    'ph': 'b',
    'id': 238,
    'args': {
      'method': 'GET',
      'uri': 'http://www.example.com/',
      'filterKey': 'HTTP/client',
      'isolateId': 'isolates/3494935576149295',
      'isolateGroupId': 'isolateGroups/12160347548294753697'
    },
    'type': 'TimelineEvent'
  },
  {
    'name': 'HTTP CLIENT GET',
    'cat': 'Dart',
    'tid': 21767,
    'pid': 81479,
    'ts': 231937100000,
    'ph': 'e',
    'id': 238,
    'args': {
      'error':
          'SocketException: Failed host lookup: \'www.example.com\' (OS Error: nodename nor servname provided, or not known, errno = 8)',
      'filterKey': 'HTTP/client',
      'isolateId': 'isolates/3494935576149295',
      'isolateGroupId': 'isolateGroups/12160347548294753697'
    },
    'type': 'TimelineEvent'
  },
];

const _invalidStartTime = 231938000000;
final httpInvalidEvent = HttpRequestData.fromTimeline(
  timelineMicrosBase: _invalidStartTime - 1000000, // - 1000000 is arbitrary.
  requestEvents: httpInvalidEventTrace,
  responseEvents: [],
);
final httpInvalidEventTrace = [
  {
    'name': 'HTTP CLIENT PUT',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': 231938100000,
    'ph': 'e',
    'id': '17',
    'args': {
      'requestHeaders': {
        'user-agent': ['Dart/2.8 (dart:io)'],
        'accept-encoding': ['gzip'],
        'content-length': ['0'],
        'host': ['127.0.0.1:8011']
      },
      'compressionState': 'HttpClientResponseCompressionState.notCompressed',
      'connectionInfo': {
        'localPort': 35246,
        'remoteAddress': '127.0.0.1',
        'remotePort': 8011
      },
      'contentLength': 0,
      'cookies': ['Cookie-Monster=Me-want-cookie!; HttpOnly'],
      'responseHeaders': {
        'x-frame-options': ['SAMEORIGIN'],
        'content-type': ['text/plain; charset=utf-8'],
        'x-xss-protection': ['1; mode=block'],
        'set-cookie': ['Cookie-Monster=Me-want-cookie!; HttpOnly'],
        'x-content-type-options': ['nosniff'],
        'content-length': ['0']
      },
      'isRedirect': false,
      'persistentConnection': true,
      'reasonPhrase': 'OK',
      'redirects': [],
      'statusCode': 200,
      'isolateId': 'isolates/3907117677703047'
    }
  },
];

const _inProgressStartTime = 231939000000;
final httpInProgressEvent = HttpRequestData.fromTimeline(
  timelineMicrosBase: _inProgressStartTime - 1000000, // - 1000000 is arbitrary.
  requestEvents: httpInProgressEventTrace,
  responseEvents: [],
);
final httpInProgressEventTrace = [
  {
    'name': 'HTTP CLIENT GET',
    'cat': 'Dart',
    'tid': 52414,
    'pid': 52406,
    'ts': _inProgressStartTime,
    'ph': 'b',
    'id': '1d',
    'args': {
      'filterKey': 'HTTP/client',
      'method': 'GET',
      'uri': 'http://127.0.0.1:8011/foo/bar?foo=bar&year=2019',
      'isolateId': 'isolates/3907117677703047'
    }
  },
];

final testSocket1 = WebSocket(SocketStatistic.parse(testSocket1Json), 0);
final Map<String, dynamic> testSocket1Json = {
  'id': 0,
  'startTime': 1000000,
  'endTime': 2000000,
  'lastReadTime': 1800000,
  'lastWriteTime': 1850000,
  'address': 'InternetAddress(\'2606:4700:3037::ac43:bd8f\', IPv6)',
  'port': 443,
  'socketType': 'tcp',
  'readBytes': 10,
  'writeBytes': 15,
};

final testSocket2 = WebSocket(SocketStatistic.parse(testSocket2Json), 0);
final Map<String, dynamic> testSocket2Json = {
  'id': 1,
  'startTime': 3000000,
  // This socket has no end time.
  'lastReadTime': 3500000,
  'lastWriteTime': 3600000,
  'address': 'InternetAddress(\'2606:4700:3037::ac43:0000\', IPv6)',
  'port': 80,
  'socketType': 'tcp',
  'readBytes': 20,
  'writeBytes': 25,
};

final testSocket3 = WebSocket(SocketStatistic.parse(testSocket3Json), 0);
final Map<String, dynamic> testSocket3Json = {
  'id': 0,
  'startTime': 1000000,
  'endTime': 2000000,
  'lastReadTime': 1800000,
  'lastWriteTime': 1850000,
  'address': 'InternetAddress(\'2606:4700:3037::ac43:bd8f\', IPv6)',
  'port': 443,
  'socketType': 'tcp',
  'readBytes': 100,
  'writeBytes': 150,
};
