import 'package:devtools_app/src/screens/network/utils/http_utils.dart';
import 'package:devtools_app/src/shared/http/http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateHeadersSize', () {
    test('joins JSON list values without brackets', () {
      // Header values decoded from JSON are List<dynamic>, not List<String>.
      final headers = <String, Object?>{
        'accept': <dynamic>['a', 'b'],
      };
      // 'accept: a, b\r\n' + '\r\n'
      expect(calculateHeadersSize(headers), 16);
    });

    test('counts each set-cookie value as its own line', () {
      final headers = <String, Object?>{
        'set-cookie': <dynamic>['a=1', 'b=2'],
      };
      // 'set-cookie: a=1\r\n' * 2 + '\r\n'
      expect(calculateHeadersSize(headers), 36);
    });

    test('returns -1 for null headers', () {
      expect(calculateHeadersSize(null), -1);
    });
  });

  group('headersToText', () {
    test('formats headers as key: value lines', () {
      final headers = <String, Object?>{
        'content-type': <dynamic>['application/json'],
        'content-length': <dynamic>[15],
        'accept': <dynamic>['text/html', 'application/json'],
        'statusCode': 200,
      };
      expect(
        headersToText(headers),
        'content-type: application/json\n'
        'content-length: 15\n'
        'accept: text/html, application/json\n'
        'statusCode: 200',
      );
    });

    test('puts each set-cookie value on its own line', () {
      final headers = <String, Object?>{
        'set-cookie': <dynamic>[
          'sid=1; Path=/',
          'theme=dark; Expires=Wed, 21 Oct 2026 07:28:00 GMT',
        ],
      };
      expect(
        headersToText(headers),
        'set-cookie: sid=1; Path=/\n'
        'set-cookie: theme=dark; Expires=Wed, 21 Oct 2026 07:28:00 GMT',
      );
    });

    test('joins cookie header values with a semicolon', () {
      final headers = <String, Object?>{
        'cookie': <dynamic>['a=b', 'c=d'],
      };
      expect(headersToText(headers), 'cookie: a=b; c=d');
    });

    test('treats any iterable value as a multi-value header', () {
      final headers = <String, Object?>{
        'accept': {'text/html', 'application/json'},
      };
      expect(headersToText(headers), 'accept: text/html, application/json');
    });

    test('handles null and empty headers', () {
      expect(headersToText(null), isEmpty);
      expect(headersToText({}), isEmpty);
    });
  });

  group('generalInfoToText', () {
    test('formats values as they are displayed', () {
      final info = <String, Object?>{
        'method': 'GET',
        'redirects': <dynamic>[],
        'isRedirect': false,
      };
      expect(
        generalInfoToText(info),
        'method: GET\nredirects: []\nisRedirect: false',
      );
    });
  });

  group('requestCookiesToText', () {
    test('formats cookies as a Cookie header value', () {
      final cookies = [
        Cookie.fromSetCookieValue('a=b'),
        Cookie.fromSetCookieValue('c=d'),
      ];
      expect(requestCookiesToText(cookies), 'a=b; c=d');
    });
  });

  group('responseCookiesToText', () {
    final cookies = [Cookie.fromSetCookieValue('sid=1; Path=/; Max-Age=60')];

    test('uses the raw set-cookie header values', () {
      final headers = <String, Object?>{
        'Set-Cookie': <dynamic>['sid=1; Path=/; Max-Age=60'],
      };
      expect(
        responseCookiesToText(cookies, headers),
        'sid=1; Path=/; Max-Age=60',
      );
    });

    test('falls back to name=value without a set-cookie header', () {
      expect(responseCookiesToText(cookies, null), 'sid=1');
      expect(responseCookiesToText(cookies, {}), 'sid=1');
      expect(responseCookiesToText(cookies, {'set-cookie': null}), 'sid=1');
    });
  });

  group('formatBytes', () {
    // Verifies correct formatting across different unit ranges.
    test('formats bytes correctly', () {
      expect(formatBytes(512), '512 B'); // bytes
      expect(formatBytes(2000), '2.0 kB'); // kilobytes (base-10)
      expect(formatBytes(1000000), '1.0 MB'); // megabytes (base-10)
    });

    // Ensures handling of invalid or missing values.
    test('handles null and negative values', () {
      expect(formatBytes(null), '-');
      expect(formatBytes(-1), '-');
    });
  });
}
