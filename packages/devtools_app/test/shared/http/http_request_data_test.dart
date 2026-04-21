import 'package:devtools_app/src/shared/http/http_request_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('responseBytes', () {
    Map<String, Object?> baseJson(Map<String, Object?> responseHeaders) {
      return {
        'isolateId': 'isolate-1',
        'id': 'request-1',
        'method': 'GET',
        'uri': 'https://example.com',
        'events': <Object?>[],
        'startTime': DateTime.now().microsecondsSinceEpoch,
        'endTime': DateTime.now().microsecondsSinceEpoch,
        'request': {
          'headers': <String, Object?>{},
          'connectionInfo': null,
          'contentLength': null,
          'cookies': <Object?>[],
          'followRedirects': true,
          'maxRedirects': 5,
          'persistentConnection': true,
        },
        'response': {
          'headers': responseHeaders,
          'connectionInfo': null,
          'contentLength': null,
          'cookies': <Object?>[],
          'compressionState': 'ResponseBodyCompressionState.notCompressed',
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'redirects': <Map<String, dynamic>>[],
          'statusCode': 200,
          'startTime': DateTime.now().microsecondsSinceEpoch,
        },
      };
    }

    // Verifies parsing when content-length is a string value.
    test('parses content-length from string', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({'content-length': '1234'}),
        null,
        null,
      );

      expect(request.responseBytes, 1234);
    });

    // Verifies parsing when content-length is a list of strings.
    test('parses content-length from list of strings', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({
          'content-length': ['5678'],
        }),
        null,
        null,
      );

      expect(request.responseBytes, 5678);
    });

    // Ensures integer values inside a list are handled correctly.
    test('handles integer in list', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({
          'content-length': [91011],
        }),
        null,
        null,
      );

      expect(request.responseBytes, 91011);
    });

    // Returns null when header is missing.
    test('returns null for missing header', () {
      final request = DartIOHttpRequestData.fromJson(baseJson({}), null, null);

      expect(request.responseBytes, null);
    });

    // Returns null when parsing fails.
    test('returns null for invalid value', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({'content-length': 'invalid'}),
        null,
        null,
      );

      expect(request.responseBytes, null);
    });
  });
}
