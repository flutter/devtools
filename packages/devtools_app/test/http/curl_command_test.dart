// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/http/curl_command.dart';
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
        "curl --location --request GET 'https://jsonplaceholder.typicode.com/albums/1' \\\n--header 'content-length: 0'",
      );
    });

    test('parses POST request from test_data', () {
      final command = CurlCommand.from(httpPost);

      expect(
        command.toString(),
        "curl --location --request POST 'https://jsonplaceholder.typicode.com/posts' \\\n--data-raw '{\n \"title\": \"foo\", \"body\": \"bar\", \"userId\": 1\n}\n '",
      );
    });
  });
}

class _TestDartIOHttpRequestData extends DartIOHttpRequestData {
  _TestDartIOHttpRequestData(
    this._request,
  ) : super(_request);

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
      responseBody: null,
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
