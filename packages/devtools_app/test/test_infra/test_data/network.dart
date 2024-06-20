// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:vm_service/vm_service.dart';

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
  125,
];

final testSocket1 = WebSocket(SocketStatistic.parse(testSocket1Json)!, 0);
final testSocket1Json = <String, Object?>{
  'id': '10000',
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
final testSocket2Json = <String, Object?>{
  'id': '11111',
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
final testSocket3Json = <String, Object?>{
  'id': '10000',
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
final httpGet = DartIOHttpRequestData(
  httpGetRequest,
  requestFullDataFromVmService: false,
);
final httpGetJson = <String, Object?>{
  'type': 'HttpProfileRequest',
  'id': '1',
  'isolateId': 'isolates/2013291945734727',
  'method': 'GET',
  'uri': 'https://jsonplaceholder.typicode.com/albums/1?userId=1&title=myalbum',
  'events': [
    {'timestamp': 6326808941, 'event': 'Connection established'},
    {'timestamp': 6326808965, 'event': 'Request sent'},
    {'timestamp': 6327090622, 'event': 'Waiting (TTFB)'},
    {'timestamp': 6327091650, 'event': 'Content Download'},
  ],
  'startTime': 6326279935,
  'endTime': 6326808974,
  'request': {
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
final httpPost = DartIOHttpRequestData(
  httpPostRequest,
  requestFullDataFromVmService: false,
);
final httpPostJson = <String, Object?>{
  'type': 'HttpProfileRequest',
  'id': '2',
  'isolateId': 'isolates/979700762893215',
  'method': 'POST',
  'uri': 'https://jsonplaceholder.typicode.com/posts',
  'events': [
    {'timestamp': 2400314657, 'event': 'Connection established'},
    {'timestamp': 2400320066, 'event': 'Request sent'},
    {'timestamp': 2400994822, 'event': 'Waiting (TTFB)'},
    {'timestamp': 2401000729, 'event': 'Content Download'},
  ],
  'startTime': 2399492629,
  'endTime': 2400321715,
  'request': {
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
  ...[123, 10, 32, 34, 116, 105, 116, 108, 101, 34, 58, 32, 34, 102, 111, 111],
  ...[34, 44, 32, 34, 98, 111, 100, 121, 34, 58, 32, 34, 98, 97, 114, 34],
  ...[44, 32, 34, 117, 115, 101, 114, 73, 100, 34, 58, 32, 49, 10, 125, 10, 32],
];
final httpPostResponseBodyData = [
  ...[123, 10, 32, 32, 34, 105, 100, 34, 58, 32, 49, 48, 49, 10, 125],
];

final httpPutRequest = HttpProfileRequest.parse(httpPutJson)!;
final httpPut = DartIOHttpRequestData(
  httpPutRequest,
  requestFullDataFromVmService: false,
);
final httpPutJson = <String, Object?>{
  'type': 'HttpProfileRequest',
  'id': '3',
  'isolateId': 'isolates/4447876918484683',
  'method': 'PUT',
  'uri': 'https://jsonplaceholder.typicode.com/posts/1',
  'events': [
    {'timestamp': 1205855316, 'event': 'Connection established'},
    {'timestamp': 1205858323, 'event': 'Request sent'},
    {'timestamp': 1206602445, 'event': 'Waiting (TTFB)'},
    {'timestamp': 1206609213, 'event': 'Content Download'},
  ],
  'startTime': 1205283313,
  'endTime': 1205859179,
  'request': {
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
final httpPatch = DartIOHttpRequestData(
  httpPatchRequest,
  requestFullDataFromVmService: false,
);
final httpPatchJson = <String, Object?>{
  'type': 'HttpProfileRequest',
  'id': '4',
  'isolateId': 'isolates/4447876918484683',
  'method': 'PATCH',
  'uri': 'https://jsonplaceholder.typicode.com/posts/1',
  'events': [
    {'timestamp': 1910722654, 'event': 'Connection established'},
    {'timestamp': 1910722783, 'event': 'Request sent'},
    {'timestamp': 1911415225, 'event': 'Waiting (TTFB)'},
    {'timestamp': 1911421003, 'event': 'Content Download'},
  ],
  'startTime': 1910177192,
  'endTime': 1910722856,
  'request': {
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
final httpGetWithError = DartIOHttpRequestData(
  httpGetWithErrorRequest,
  requestFullDataFromVmService: false,
);
final httpGetWithErrorJson = <String, Object?>{
  'type': '@HttpProfileRequest',
  'id': '5',
  'isolateId': 'isolates/1939772779732043',
  'method': 'GET',
  'uri': 'https://www.examplez.com/1',
  'events': [],
  'startTime': 5385227316,
  'endTime': 5387256813,
  'request': {
    'error': 'HandshakeException: Connection terminated during handshake',
  },
};

final httpWsHandshakeRequest = HttpProfileRequest.parse(httpWsHandshakeJson)!;
final httpWsHandshake = DartIOHttpRequestData(
  httpWsHandshakeRequest,
  requestFullDataFromVmService: false,
);
final httpWsHandshakeJson = <String, Object?>{
  'type': 'HttpProfileRequest',
  'id': '6',
  'isolateId': 'isolates/1350291957483171',
  'method': 'GET',
  'uri': 'http://localhost:8080',
  'events': [
    {'timestamp': 8140247076, 'event': 'Connection established'},
    {'timestamp': 8140247156, 'event': 'Request sent'},
    {'timestamp': 8140261573, 'event': 'Waiting (TTFB)'},
  ],
  'startTime': 8140222102,
  'endTime': 8140247377,
  'request': {
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

final httpGetPendingJson = <String, Object?>{
  'type': 'HttpProfileRequest',
  'id': '7',
  'isolateId': 'isolates/2013291945734727',
  'method': 'GET',
  'uri': 'https://jsonplaceholder.typicode.com/albums/10',
  'events': [
    {'timestamp': 6326808941, 'event': 'Connection established'},
    {'timestamp': 6326808965, 'event': 'Request sent'},
    {'timestamp': 6327090622, 'event': 'Waiting (TTFB)'},
    {'timestamp': 6327091650, 'event': 'Content Download'},
  ],
  'startTime': 6326279935,
  'endTime': 6326808974,
  'request': {
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
  'requestBody': [],
};
