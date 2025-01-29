// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('url utils', () {
    group('extractCurrentPageFromUrl', () {
      test('parses the current page from the path', () {
        final page = extractCurrentPageFromUrl(
          'http://localhost:9000/inspector?uri=x',
        );
        expect(page, 'inspector');
      });

      test('parses the current page from the query string', () {
        final page = extractCurrentPageFromUrl(
          'http://localhost:9000/?uri=x&page=inspector&theme=dark',
        );
        expect(page, 'inspector');
      });

      test(
        'parses the current page from the path even if query string is populated',
        () {
          final page = extractCurrentPageFromUrl(
            'http://localhost:9000/memory?uri=x&page=inspector&theme=dark',
          );
          expect(page, 'memory');
        },
      );
    });

    group('mapLegacyUrl', () {
      for (final prefix in [
        'http://localhost:123',
        'http://localhost:123/authToken=/devtools',
      ]) {
        group(' with $prefix prefix', () {
          test('does not map new-style URLs', () {
            expect(mapLegacyUrl(prefix), isNull);
            expect(mapLegacyUrl('$prefix/'), isNull);
            expect(mapLegacyUrl('$prefix/foo?uri=ws://foo'), isNull);
            expect(mapLegacyUrl('$prefix?uri=ws://foo'), isNull);
            expect(mapLegacyUrl('$prefix/?uri=ws://foo'), isNull);
            expect(mapLegacyUrl('$prefix/?uri=ws://foo#'), isNull);
          });

          test('maps legacy URIs with page names in path', () {
            expect(
              mapLegacyUrl('$prefix/#/inspector?foo=bar'),
              '$prefix/inspector?foo=bar',
            );
          });

          test('maps legacy URIs with page names in querystring', () {
            expect(
              mapLegacyUrl('$prefix/#/?page=inspector&foo=bar'),
              '$prefix/inspector?foo=bar',
            );
          });

          test('maps legacy URIs with no page names', () {
            expect(mapLegacyUrl('$prefix/#/?foo=bar'), '$prefix/?foo=bar');
          });
        });
      }
    });
  });
}
