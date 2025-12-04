// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/network/utils/http_utils.dart';
import 'package:test/test.dart';

void main() {
  group('isTextMimeType', () {
    test('returns true for text/* types', () {
      expect(isTextMimeType('text/plain'), isTrue);
      expect(isTextMimeType('text/html'), isTrue);
      expect(isTextMimeType('text/css'), isTrue);
    });

    test('returns true for common textual application/* types', () {
      expect(isTextMimeType('application/json'), isTrue);
      expect(isTextMimeType('application/javascript'), isTrue);
      expect(isTextMimeType('application/xml'), isTrue);
    });

    test('returns true even if charset parameter is present', () {
      expect(isTextMimeType('application/json; charset=utf-8'), isTrue);
      expect(isTextMimeType('text/html; charset=UTF-8'), isTrue);
    });

    test('returns false for non-text types', () {
      expect(isTextMimeType('image/png'), isFalse);
      expect(isTextMimeType('application/octet-stream'), isFalse);
      expect(isTextMimeType('video/mp4'), isFalse);
      expect(isTextMimeType('audio/mpeg'), isFalse);
    });

    test('returns false for null or empty strings', () {
      expect(isTextMimeType(null), isFalse);
      expect(isTextMimeType(''), isFalse);
      expect(isTextMimeType('   '), isFalse);
    });

    test('is case-insensitive', () {
      expect(isTextMimeType('Application/Json'), isTrue);
      expect(isTextMimeType('TEXT/HTML'), isTrue);
    });
  });

  group('getHeadersMimeType', () {
    test('extracts MIME type from a plain string', () {
      expect(
        getHeadersMimeType('application/json; charset=utf-8'),
        'application/json',
      );
      expect(getHeadersMimeType('text/html; charset=UTF-8'), 'text/html');
    });

    test('extracts MIME type from a list of strings', () {
      expect(
        getHeadersMimeType(['application/json; charset=utf-8']),
        'application/json',
      );
      expect(getHeadersMimeType(['text/css; something']), 'text/css');
    });

    test('returns null for empty or null inputs', () {
      expect(getHeadersMimeType(null), isNull);
      expect(getHeadersMimeType(''), isNull);
      expect(getHeadersMimeType('   '), isNull);
      expect(getHeadersMimeType([]), isNull);
      expect(getHeadersMimeType(['']), isNull);
    });

    test('normalizes to lowercase', () {
      expect(getHeadersMimeType('Text/HTML; Charset=UTF-8'), 'text/html');
      expect(getHeadersMimeType(['APPLICATION/JSON']), 'application/json');
    });

    test('handles unexpected header formats gracefully', () {
      expect(getHeadersMimeType(['; charset=utf-8']), isNull);
      expect(getHeadersMimeType(['   ;   ']), isNull);
    });
  });
}
