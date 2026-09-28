// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:typed_data';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/http/curl_command.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/network.dart';

void main() {
  group('NetworkCurlCommand', () {
    test('parses simple GET request', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'GET',
          uri: Uri.parse('https://www.example.com'),
        ),
      );

      expect(
        command.toString(),
        "curl --location --request GET 'https://www.example.com'",
      );
    });

    test('parses PUT request', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'PUT',
          uri: Uri.parse('https://www.example.com'),
          headers: {},
        ),
      );

      expect(
        command.toString(),
        "curl --location --request PUT 'https://www.example.com'",
      );
    });

    test('parses simple GET request with headers', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'GET',
          uri: Uri.parse('https://www.example.com'),
          headers: {
            'accept-language': ['en-GB,de-DE'],
            'user-agent': ['SomeUserAgent/5.0 (Macintosh; Intel Mac OS X)'],
          },
        ),
      );

      expect(
        command.toString(),
        "curl --location --request GET 'https://www.example.com' \\\n--header 'accept-language: en-GB,de-DE' \\\n--header 'user-agent: SomeUserAgent/5.0 (Macintosh; Intel Mac OS X)'",
      );
    });

    test('parses POST with body', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'POST',
          uri: Uri.parse('https://www.example.com'),
          headers: {
            'accept-language': ['en-GB,de-DE'],
            'user-agent': ['SomeUserAgent/5.0 (Macintosh; Intel Mac OS X)'],
          },
          requestBody: Uint8List.fromList(
            'It\'s a request body!\nHopefully this works.'.codeUnits,
          ),
        ),
      );

      expect(
        command.toString(),
        "curl --location --request POST 'https://www.example.com' \\\n--header 'accept-language: en-GB,de-DE' \\\n--header 'user-agent: SomeUserAgent/5.0 (Macintosh; Intel Mac OS X)' \\\n--data-raw 'It'\\''s a request body!\nHopefully this works.'",
      );
    });

    test('parses null body', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'POST',
          uri: Uri.parse('https://www.example.com'),
          headers: {},
          // Ignore this warning to make the `null` value used more apparent
          // ignore: avoid_redundant_argument_values
          requestBody: null,
        ),
      );

      expect(
        command.toString(),
        "curl --location --request POST 'https://www.example.com'",
      );
    });

    test('parses empty body', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'POST',
          uri: Uri.parse('https://www.example.com'),
          headers: {},
          requestBody: Uint8List(0),
        ),
      );

      expect(
        command.toString(),
        "curl --location --request POST 'https://www.example.com' \\\n--data-raw ''",
      );
    });

    test('escapes \' character in url', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'GET',
          uri: Uri.parse('https://www.example.com/search?q=\'test\''),
          headers: {
            'accept-language': ['en-GB,de-DE'],
            'user-agent': ['SomeUserAgent/5.0 (Macintosh; Intel Mac OS X)'],
          },
        ),
      );

      expect(
        command.toString(),
        "curl --location --request GET 'https://www.example.com/search?q='\\''test'\\''' \\\n--header 'accept-language: en-GB,de-DE' \\\n--header 'user-agent: SomeUserAgent/5.0 (Macintosh; Intel Mac OS X)'",
      );
    });

    test('escapes \' character in headers', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'GET',
          uri: Uri.parse('https://www.example.com'),
          headers: {
            'accept-language': ['en-GB,de-DE'],
            'authorization': ['Bearer \'this is a\' test'],
          },
        ),
      );

      expect(
        command.toString(),
        "curl --location --request GET 'https://www.example.com' \\\n--header 'accept-language: en-GB,de-DE' \\\n--header 'authorization: Bearer '\\''this is a'\\'' test'",
      );
    });

    test('no line breaks when "multiline" is false', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'POST',
          uri: Uri.parse('https://www.example.com'),
          headers: {
            'accept-language': ['en-GB,de-DE'],
            'authorization': ['Bearer \'this is a\' test'],
          },
          requestBody: Uint8List(0),
        ),
        multiline: false,
      );

      expect(
        command.toString(),
        "curl --location --request POST 'https://www.example.com' --header 'accept-language: en-GB,de-DE' --header 'authorization: Bearer '\\''this is a'\\'' test' --data-raw ''",
      );
    });

    test('no --location when followRedirects is false', () {
      final command = CurlCommand.from(
        _testDartIOHttpRequestData(
          method: 'GET',
          uri: Uri.parse('https://www.example.com'),
          headers: {},
        ),
        multiline: false,
        followRedirects: false,
      );

      expect(
        command.toString(),
        "curl --request GET 'https://www.example.com'",
      );
    });

    test('parses GET request from test_data', () {
      final command = CurlCommand.from(httpGet);

      expect(
        command.toString(),
        "curl --location --request GET 'https://jsonplaceholder.typicode.com/albums/1?userId=1&title=myalbum' \\\n--header 'content-length: 0'",
      );
    });

    test('parses POST request from test_data', () {
      final command = CurlCommand.from(httpPost);

      expect(
        command.toString(),
        "curl --location --request POST 'https://jsonplaceholder.typicode.com/posts' \\\n--data-raw '{\n \"title\": \"foo\", \"body\": \"bar\", \"userId\": 1\n}\n '",
      );
    });

    test('includes headers and body when response never completes', () {
      final data = DartIOHttpRequestData(
        HttpProfileRequest.parse(<String, Object?>{
          'id': '7',
          'isolateId': 'isolates/0',
          'method': 'POST',
          'uri': 'https://example.com/api/login',
          'events': <Object>[],
          'startTime': 0,
          'endTime': 1000,
          'request': <String, Object?>{
            'headers': <String, Object?>{
              'content-type': <String>['application/json'],
              'accept': <String>['application/json'],
              'locale': <String>['en'],
            },
            'contentLength': 42,
            'cookies': <Object>[],
            'followRedirects': true,
            'maxRedirects': 5,
            'persistentConnection': false,
          },
          'response': null,
          'requestBody': utf8.encode(
            '{"email":"user@example.com","password":"secret"}',
          ),
        })!,
        requestFullDataFromVmService: false,
      );

      expect(
        data.requestBody,
        '{"email":"user@example.com","password":"secret"}',
      );
      expect(
        CurlCommand.from(data).toString(),
        "curl --location --request POST 'https://example.com/api/login' \\\n--header 'content-type: application/json' \\\n--header 'accept: application/json' \\\n--header 'locale: en' \\\n--data-raw '{\"email\":\"user@example.com\",\"password\":\"secret\"}'",
      );
    });

    test('includes body when request has an error', () {
      final data = DartIOHttpRequestData(
        HttpProfileRequest.parse(<String, Object?>{
          'id': '8',
          'isolateId': 'isolates/0',
          'method': 'POST',
          'uri': 'https://example.com/api/login',
          'events': <Object>[],
          'startTime': 0,
          'endTime': 1000,
          'request': <String, Object?>{
            'error': 'Connection timed out',
            'contentLength': 2,
            'cookies': <Object>[],
            'followRedirects': true,
            'maxRedirects': 5,
            'persistentConnection': false,
          },
          'response': null,
          'requestBody': utf8.encode('{}'),
        })!,
        requestFullDataFromVmService: false,
      );

      expect(data.requestBody, '{}');
      expect(CurlCommand.from(data).toString(), contains("--data-raw '{}'"));
    });
  });

  // Regression coverage for the request body across the lifecycle of a
  // request in the Network tab. The body is known once the request has been
  // sent, so it must be available for Copy as cURL whether the request is
  // still awaiting its response, completed, or failed, and it must survive the
  // profile refreshes that replace the underlying request while it is pending.
  // See https://github.com/flutter/devtools/pull/9963.
  group('NetworkCurlCommand request body lifecycle', () {
    const body = '{"email":"user@example.com"}';
    const curlWithHeaderAndBody =
        "curl --location --request POST 'https://example.com/api/login' "
        "\\\n--header 'content-type: application/json' "
        "\\\n--data-raw '$body'";

    test('includes body for a pending request awaiting its response', () {
      final data = DartIOHttpRequestData(
        _parseProfileRequest(
          requestSent: true,
          response: null,
          requestBody: utf8.encode(body),
        ),
        requestFullDataFromVmService: false,
      );

      expect(data.inProgress, isTrue);
      expect(data.requestBody, body);
      expect(CurlCommand.from(data).toString(), curlWithHeaderAndBody);
    });

    test('includes body for a completed request', () {
      final data = DartIOHttpRequestData(
        _parseProfileRequest(
          requestSent: true,
          response: _completedResponseJson,
          requestBody: utf8.encode(body),
        ),
        requestFullDataFromVmService: false,
      );

      expect(data.inProgress, isFalse);
      expect(data.requestBody, body);
      expect(CurlCommand.from(data).toString(), curlWithHeaderAndBody);
    });

    test('includes body for a request that failed without a response', () {
      final data = DartIOHttpRequestData(
        _parseProfileRequest(
          requestSent: true,
          requestError: 'Connection timed out',
          response: null,
          requestBody: utf8.encode(body),
        ),
        requestFullDataFromVmService: false,
      );

      expect(data.didFail, isTrue);
      expect(data.requestBody, body);
      expect(CurlCommand.from(data).toString(), contains("--data-raw '$body'"));
    });

    // These tests exercise `getFullRequestData`, which fetches the body from
    // the VM service when a request is selected, followed by `merge` calls
    // that simulate `getHttpProfile` polling.
    group('with VM service', () {
      tearDown(() => removeGlobal(ServiceConnectionManager));

      test(
        'retains body fetched while pending across profile refreshes',
        () async {
          _serveFullRequestFromVmService(
            _parseProfileRequest(
              requestSent: true,
              response: null,
              requestBody: utf8.encode(body),
            ),
          );

          // Entries from `getHttpProfile` polling never carry bodies.
          final data = DartIOHttpRequestData(
            _parseProfileRequest(requestSent: true, response: null),
            requestFullDataFromVmService: false,
          );

          // Selecting the request in the Network tab fetches its full data.
          await data.getFullRequestData();
          expect(data.inProgress, isTrue);
          expect(data.requestBody, body);
          expect(CurlCommand.from(data).toString(), curlWithHeaderAndBody);

          // The next poll replaces the profile entry while still pending.
          data.merge(
            DartIOHttpRequestData(
              _parseProfileRequest(requestSent: true, response: null),
              requestFullDataFromVmService: false,
            ),
          );
          expect(data.inProgress, isTrue);
          expect(data.requestBody, body);
          expect(CurlCommand.from(data).toString(), curlWithHeaderAndBody);

          // The response eventually completes.
          data.merge(
            DartIOHttpRequestData(
              _parseProfileRequest(
                requestSent: true,
                response: _completedResponseJson,
              ),
              requestFullDataFromVmService: false,
            ),
          );
          expect(data.inProgress, isFalse);
          expect(data.requestBody, body);
          expect(CurlCommand.from(data).toString(), curlWithHeaderAndBody);
        },
      );
    });
  });
}

/// Sets up a fake VM service whose `getHttpProfileRequest` returns [request].
void _serveFullRequestFromVmService(HttpProfileRequest request) {
  setGlobal(
    ServiceConnectionManager,
    FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        httpProfile: HttpProfile(
          requests: [request],
          timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
        ),
      ),
    ),
  );
}

/// Parses an [HttpProfileRequest] shaped like the dart:io HTTP profiler JSON.
///
/// dart:io only reports `endTime` and `request` once the request has been
/// fully sent ([requestSent]), and `response` once a response starts.
HttpProfileRequest _parseProfileRequest({
  required bool requestSent,
  required Map<String, Object?>? response,
  String? requestError,
  List<int>? requestBody,
}) {
  return HttpProfileRequest.parse({
    'id': '1',
    'isolateId': 'isolates/0',
    'method': 'POST',
    'uri': 'https://example.com/api/login',
    'events': <Object>[],
    'startTime': 0,
    if (requestSent) ...{
      'endTime': 1000,
      'request': requestError != null
          ? {'error': requestError}
          : {
              'headers': {
                'content-type': ['application/json'],
              },
              'connectionInfo': <String, Object?>{},
              'contentLength': requestBody?.length ?? 0,
              'cookies': <Object>[],
              'followRedirects': true,
              'maxRedirects': 5,
              'persistentConnection': true,
            },
    },
    'response': ?response,
    'requestBody': ?requestBody,
  })!;
}

const _completedResponseJson = <String, Object?>{
  'startTime': 2000,
  'endTime': 3000,
  'headers': <String, Object?>{},
  'compressionState': 'notCompressed',
  'connectionInfo': <String, Object?>{},
  'contentLength': 0,
  'cookies': <Object>[],
  'isRedirect': false,
  'persistentConnection': true,
  'reasonPhrase': 'OK',
  'redirects': <Object>[],
  'statusCode': 200,
};

class _TestDartIOHttpRequestData extends DartIOHttpRequestData {
  _TestDartIOHttpRequestData(this._request) : super(_request);

  final HttpProfileRequest _request;

  @override
  String? get requestBody {
    final body = super.requestBody;
    if (body != null) {
      return body;
    }

    if (_request.requestBody != null) {
      return String.fromCharCodes(_request.requestBody!);
    }

    return null;
  }

  @override
  Future<void> getFullRequestData() async {
    // Do nothing
  }
}

DartIOHttpRequestData _testDartIOHttpRequestData({
  required String method,
  required Uri uri,
  Uint8List? requestBody,
  Map<String, dynamic>? headers,
  List<String>? cookies,
}) {
  return _TestDartIOHttpRequestData(
    HttpProfileRequest(
      id: '0',
      isolateId: '0',
      method: method,
      uri: uri,
      requestBody: requestBody,
      events: [],
      startTime: DateTime.fromMicrosecondsSinceEpoch(0),
      endTime: DateTime.fromMicrosecondsSinceEpoch(0),
      response: HttpProfileResponseData(
        compressionState: '',
        connectionInfo: {},
        contentLength: 0,
        cookies: [],
        headers: {},
        isRedirect: false,
        persistentConnection: false,
        reasonPhrase: '',
        redirects: [],
        startTime: DateTime.fromMicrosecondsSinceEpoch(0),
        statusCode: 200,
        endTime: DateTime.fromMicrosecondsSinceEpoch(0),
      ),
      request: HttpProfileRequestData.buildSuccessfulRequest(
        headers: headers ?? {},
        connectionInfo: {},
        contentLength: requestBody?.length ?? 0,
        cookies: cookies ?? [],
        followRedirects: false,
        maxRedirects: 0,
        persistentConnection: false,
      ),
    ),
  );
}
