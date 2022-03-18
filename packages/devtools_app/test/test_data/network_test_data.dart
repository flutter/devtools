// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/devtools_app.dart';
import 'package:vm_service/vm_service.dart';

const _getStartTime = 231935000000;
final httpGetEvent = TimelineHttpRequestData.fromTimeline(
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
final httpPutEvent = TimelineHttpRequestData.fromTimeline(
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
final httpGetEventWithError = TimelineHttpRequestData.fromTimeline(
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
final httpInvalidEvent = TimelineHttpRequestData.fromTimeline(
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
final httpInProgressEvent = TimelineHttpRequestData.fromTimeline(
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

final testSocket1 = WebSocket(SocketStatistic.parse(testSocket1Json)!, 0);
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

final testSocket2 = WebSocket(SocketStatistic.parse(testSocket2Json)!, 0);
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

final testSocket3 = WebSocket(SocketStatistic.parse(testSocket3Json)!, 0);
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

final httpGetRequest = HttpProfileRequest.parse(httpGetJson)!;
final httpGet = DartIOHttpRequestData(0, httpGetRequest);
final Map<String, dynamic> httpGetJson = {
  'type': 'HttpProfileRequest',
  'id': 1,
  'isolateId': 'isolates/2013291945734727',
  'method': 'GET',
  'uri': 'https://jsonplaceholder.typicode.com/albums/1',
  'startTime': 6326279935,
  'endTime': 6326808974,
  'request': {
    'events': [
      {'timestamp': 6326808941, 'event': 'Connection established'},
      {'timestamp': 6326808965, 'event': 'Request sent'},
      {'timestamp': 6327090622, 'event': 'Waiting (TTFB)'},
      {'timestamp': 6327091650, 'event': 'Content Download'}
    ],
    'headers': {
      'content-length': ['0'],
    },
    'connectionInfo': {
      'localPort': 45648,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': 0,
    'cookies': [],
    'followRedirects': true,
    'maxRedirects': 5,
    'method': 'GET',
    'persistentConnection': true,
    'uri': 'https://jsonplaceholder.typicode.com/albums/1',
    'filterKey': 'HTTP/client',
  },
  'response': {
    'startTime': 6327090749,
    'headers': {
      'content-encoding': ['gzip'],
      'pragma': ['no-cache'],
      'connection': ['keep-alive'],
      'cache-control': ['max-age=43200'],
      'content-type': ['application/json; charset=utf-8'],
    },
    'compressionState': 'HttpClientResponseCompressionState.decompressed',
    'connectionInfo': {
      'localPort': 45648,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': -1,
    'cookies': [],
    'isRedirect': false,
    'persistentConnection': true,
    'reasonPhrase': 'OK',
    'redirects': [],
    'statusCode': 200,
    'endTime': 6327091628,
  },
  'requestBody': [],
  'responseBody': httpGetResponseBodyData,
};

final httpPostRequest = HttpProfileRequest.parse(httpPostJson)!;
final httpPost = DartIOHttpRequestData(0, httpPostRequest);
final Map<String, dynamic> httpPostJson = {
  'type': 'HttpProfileRequest',
  'id': 2,
  'isolateId': 'isolates/979700762893215',
  'method': 'POST',
  'uri': 'https://jsonplaceholder.typicode.com/posts',
  'startTime': 2399492629,
  'endTime': 2400321715,
  'request': {
    'events': [
      {'timestamp': 2400314657, 'event': 'Connection established'},
      {'timestamp': 2400320066, 'event': 'Request sent'},
      {'timestamp': 2400994822, 'event': 'Waiting (TTFB)'},
      {'timestamp': 2401000729, 'event': 'Content Download'},
    ],
    'headers': {
      'transfer-encoding': [],
    },
    'connectionInfo': {
      'localPort': 55972,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': -1,
    'cookies': [],
    'followRedirects': true,
    'maxRedirects': 5,
    'method': 'POST',
    'persistentConnection': true,
    'uri': 'https://jsonplaceholder.typicode.com/posts',
    'filterKey': 'HTTP/client',
  },
  'response': {
    'startTime': 2400995842,
    'headers': {
      'date': ['Wed, 04 Aug 2021 07:57:26 GMT'],
      'location': ['http://jsonplaceholder.typicode.com/posts/101'],
      'content-length': [15],
      'connection': ['keep-alive'],
      'cache-control': ['no-cache'],
      'content-type': ['application/json; charset=utf-8'],
      'x-powered-by': ['Express'],
      'expires': [-1],
    },
    'compressionState': 'HttpClientResponseCompressionState.notCompressed',
    'connectionInfo': {
      'localPort': 55972,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': 15,
    'cookies': [],
    'isRedirect': false,
    'persistentConnection': true,
    'reasonPhrase': 'Created',
    'redirects': [],
    'statusCode': 201,
    'endTime': 2401000670,
  },
  'requestBody': httpPostRequestBodyData,
  'responseBody': httpPostResponseBodyData,
};
final httpPostRequestBodyData = [
  ...[32, 32, 32, 32, 123, 10, 32, 32, 32, 32, 32, 32, 116, 105, 116, 108],
  ...[101, 58, 32, 39, 102, 111, 111, 39, 44, 10, 32, 32, 32, 32, 32, 32],
  ...[98, 111, 100, 121, 58, 32, 39, 98, 97, 114, 39, 44, 10, 32, 32, 32],
  ...[32, 32, 32, 117, 115, 101, 114, 73, 100, 58, 32, 49, 44, 10, 32, 32],
  ...[32, 32, 125, 10, 32, 32, 32, 32],
];
final httpPostResponseBodyData = [
  ...[123, 10, 32, 32, 34, 105, 100, 34, 58, 32, 49, 48, 49, 10, 125],
];

final httpPutRequest = HttpProfileRequest.parse(httpPutJson)!;
final httpPut = DartIOHttpRequestData(0, httpPutRequest);
final Map<String, dynamic> httpPutJson = {
  'type': 'HttpProfileRequest',
  'id': 3,
  'isolateId': 'isolates/4447876918484683',
  'method': 'PUT',
  'uri': 'https://jsonplaceholder.typicode.com/posts/1',
  'startTime': 1205283313,
  'endTime': 1205859179,
  'request': {
    'events': [
      {'timestamp': 1205855316, 'event': 'Connection established'},
      {'timestamp': 1205858323, 'event': 'Request sent'},
      {'timestamp': 1206602445, 'event': 'Waiting (TTFB)'},
      {'timestamp': 1206609213, 'event': 'Content Download'},
    ],
    'headers': {
      'transfer-encoding': [],
    },
    'connectionInfo': {
      'localPort': 43684,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': -1,
    'cookies': [],
    'followRedirects': true,
    'maxRedirects': 5,
    'method': 'PUT',
    'persistentConnection': true,
    'uri': 'https://jsonplaceholder.typicode.com/posts/1',
    'filterKey': 'HTTP/client',
  },
  'response': {
    'startTime': 1206603670,
    'headers': {
      'connection': ['keep-alive'],
      'cache-control': ['no-cache'],
      'date': ['Wed, 04 Aug 2021 08:57:24 GMT'],
      'content-type': ['application/json; charset=utf-8'],
      'pragma': ['no-cache'],
      'access-control-allow-credentials': [true],
      'content-length': [13],
      'expires': [-1],
    },
    'compressionState': 'HttpClientResponseCompressionState.notCompressed',
    'connectionInfo': {
      'localPort': 43684,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': 13,
    'cookies': [],
    'isRedirect': false,
    'persistentConnection': true,
    'reasonPhrase': 'OK',
    'redirects': [],
    'statusCode': 200,
    'endTime': 1206609144,
  },
  'requestBody': httpPutRequestBodyData,
  'responseBody': httpPutResponseBodyData,
};
final httpPutRequestBodyData = [
  ...[32, 32, 32, 32, 123, 10, 32, 32, 32, 32, 32, 32, 116, 105, 116, 108],
  ...[101, 58, 32, 39, 102, 111, 111, 39, 44, 10, 32, 32, 32, 32, 32, 32],
  ...[98, 111, 100, 121, 58, 32, 39, 98, 97, 114, 39, 44, 10, 32, 32, 32],
  ...[32, 32, 32, 117, 115, 101, 114, 73, 100, 58, 32, 49, 44, 10, 32, 32],
  ...[32, 32, 125, 10, 32, 32, 32, 32],
];
final httpPutResponseBodyData = [
  ...[123, 10, 32, 32, 34, 105, 100, 34, 58, 32, 49, 48, 49, 10, 125],
];

final httpPatchRequest = HttpProfileRequest.parse(httpPatchJson)!;
final httpPatch = DartIOHttpRequestData(0, httpPatchRequest);
final Map<String, dynamic> httpPatchJson = {
  'type': 'HttpProfileRequest',
  'id': 4,
  'isolateId': 'isolates/4447876918484683',
  'method': 'PATCH',
  'uri': 'https://jsonplaceholder.typicode.com/posts/1',
  'startTime': 1910177192,
  'endTime': 1910722856,
  'request': {
    'events': [
      {'timestamp': 1910722654, 'event': 'Connection established'},
      {'timestamp': 1910722783, 'event': 'Request sent'},
      {'timestamp': 1911415225, 'event': 'Waiting (TTFB)'},
      {'timestamp': 1911421003, 'event': 'Content Download'},
    ],
    'headers': {
      'transfer-encoding': [],
    },
    'connectionInfo': {
      'localPort': 43864,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': -1,
    'cookies': [],
    'followRedirects': true,
    'maxRedirects': 5,
    'method': 'PATCH',
    'persistentConnection': true,
    'uri': 'https://jsonplaceholder.typicode.com/posts/1',
    'filterKey': 'HTTP/client',
  },
  'response': {
    'startTime': 1911415812,
    'headers': {
      'connection': ['keep-alive'],
      'cache-control': ['no-cache'],
      'transfer-encoding': ['chunked'],
      'date': ['Wed, 04 Aug 2021 09:09:09 GMT'],
      'content-encoding': ['gzip'],
      'content-type': ['application/json; charset=utf-8'],
      'pragma': ['no-cache'],
      'expires': [-1],
    },
    'compressionState': 'HttpClientResponseCompressionState.decompressed',
    'connectionInfo': {
      'localPort': 43864,
      'remoteAddress': '2606:4700:3033::ac43:bdd9',
      'remotePort': 443,
    },
    'contentLength': -1,
    'cookies': [],
    'isRedirect': false,
    'persistentConnection': true,
    'reasonPhrase': 'OK',
    'redirects': [],
    'statusCode': 200,
    'endTime': 1911420918,
  },
  'requestBody': httpPatchRequestBodyData,
  'responseBody': httpPatchResponseBodyData,
};
final httpPatchRequestBodyData = [
  ...[32, 32, 32, 32, 123, 10, 32, 32, 32, 32, 32, 32, 116, 105, 116, 108],
  ...[101, 58, 32, 39, 102, 111, 111, 39, 44, 10, 32, 32, 32, 32, 32, 32],
  ...[98, 111, 100, 121, 58, 32, 39, 98, 97, 114, 39, 44, 10, 32, 32, 32],
  ...[32, 32, 32, 117, 115, 101, 114, 73, 100, 58, 32, 49, 44, 10, 32, 32],
  ...[32, 32, 125, 10, 32, 32, 32, 32],
];
final httpPatchResponseBodyData = [
  ...[123, 10, 32, 32, 34, 116, 105, 116, 108, 101, 34, 58, 32, 34, 102, 111],
  ...[111, 34, 44, 10, 32, 32, 34, 98, 111, 100, 121, 34, 58, 32, 34, 98, 97],
  ...[114, 34, 44, 10, 32, 32, 34, 117, 115, 101, 114, 73, 100, 34, 58, 32, 49],
  ...[10, 125],
];

final httpGetWithErrorRequest = HttpProfileRequest.parse(httpGetWithErrorJson)!;
final httpGetWithError = DartIOHttpRequestData(0, httpGetWithErrorRequest);
final Map<String, dynamic> httpGetWithErrorJson = {
  'type': '@HttpProfileRequest',
  'id': 5,
  'isolateId': 'isolates/1939772779732043',
  'method': 'GET',
  'uri': 'https://www.examplez.com/1',
  'startTime': 5385227316,
  'endTime': 5387256813,
  'request': {
    'events': [],
    'error': 'HandshakeException: Connection terminated during handshake',
  },
};

final httpWsHandshakeRequest = HttpProfileRequest.parse(httpWsHandshakeJson)!;
final httpWsHandshake = DartIOHttpRequestData(0, httpWsHandshakeRequest);
final Map<String, dynamic> httpWsHandshakeJson = {
  'type': 'HttpProfileRequest',
  'id': 6,
  'isolateId': 'isolates/1350291957483171',
  'method': 'GET',
  'uri': 'http://localhost:8080',
  'startTime': 8140222102,
  'endTime': 8140247377,
  'request': {
    'events': [
      {'timestamp': 8140247076, 'event': 'Connection established'},
      {'timestamp': 8140247156, 'event': 'Request sent'},
      {'timestamp': 8140261573, 'event': 'Waiting (TTFB)'}
    ],
    'headers': {
      'content-length': ['0'],
    },
    'connectionInfo': {
      'localPort': 56744,
      'remoteAddress': '127.0.0.1',
      'remotePort': 8080,
    },
    'contentLength': 0,
    'cookies': [],
    'followRedirects': true,
    'maxRedirects': 5,
    'method': 'GET',
    'persistentConnection': true,
    'uri': 'http://localhost:8080',
    'filterKey': 'HTTP/client',
  },
  'response': {
    'startTime': 8140262898,
    'headers': {
      'connection': ['Upgrade'],
      'upgrade': ['websocket'],
      'content-length': [0],
      'sec-websocket-version': [13],
      'sec-websocket-accept': ['JF5SBCGrfyYAoLKzvj6A0ZVpk6c='],
    },
    'compressionState': 'HttpClientResponseCompressionState.notCompressed',
    'connectionInfo': {
      'localPort': 56744,
      'remoteAddress': '127.0.0.1',
      'remotePort': 8080,
    },
    'contentLength': 0,
    'cookies': [],
    'isRedirect': false,
    'persistentConnection': true,
    'reasonPhrase': 'Switching Protocols',
    'redirects': [],
    'statusCode': 101,
    'endTime': 8140263470,
    'error': 'Socket has been detached',
  },
  'requestBody': [],
  'responseBody': [],
};
