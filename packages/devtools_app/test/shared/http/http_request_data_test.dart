import 'package:devtools_app/src/shared/http/http_request_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('responseBytes', () {
    Map<String, dynamic> baseJson(Map<String, Object?> headers) {
      return {
        'method': 'GET',
        'uri': 'https://example.com',
        'status': 200,
        'responseHeaders': headers,
      };
    }

    // Verifies parsing when content-length is a string value.
    test('parses content-length from string', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({'content-length': '1234'}),
        null, // requestPostData not used for this test
        null, // responseContent not used for this test
      );

      expect(request.responseBytes, 1234);
    });

    // Verifies parsing when content-length is a list of strings.
    test('parses content-length from list of strings', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({'content-length': '5678'}),
        null, // requestPostData not used for this test
        null, // responseContent not used for this test
      );

      expect(request.responseBytes, 5678);
    });

    // Ensures integer values inside a list are handled correctly.
    test('handles integer in list', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({'content-length': '91011'}),
        null, // requestPostData not used for this test
        null, // responseContent not used for this test
      );

      expect(request.responseBytes, 91011);
    });

    // Returns null when header is missing.
    test('returns null for missing header', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({}), // No content-length header
        null, // requestPostData not used for this test
        null, // responseContent not used for this test
      );

      expect(request.responseBytes, null);
    });

    // Returns null when parsing fails.
    test('returns null for invalid value', () {
      final request = DartIOHttpRequestData.fromJson(
        baseJson({'content-length': 'invalid'}),
        null, // requestPostData not used for this test
        null, // responseContent not used for this test
      );

      expect(request.responseBytes, null);
    });
  });
}
