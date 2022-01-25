// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/primitives/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('url utils', () {
    test('getSimplePackageUrl', () {
      expect(getSimplePackageUrl(''), equals(''));
      expect(getSimplePackageUrl(dartSdkUrl), equals('dart:async/zone.dart'));
      expect(
        getSimplePackageUrl(flutterUrl),
        equals('package:flutter/widgets/binding.dart'),
      );
      expect(
        getSimplePackageUrl(flutterUrlFromNonFlutterDir),
        equals('package:flutter/widgets/binding.dart'),
      );
      expect(
        getSimplePackageUrl('org-dartlang-sdk:///flutter/lib/ui/hooks.dart'),
        equals('dart:ui/hooks.dart'),
      );
    });

    group('extractCurrentPageFromUrl', () {
      test('parses the current page from the path', () {
        final page =
            extractCurrentPageFromUrl('http://localhost:9000/inspector?uri=x');
        expect(page, 'inspector');
      });

      test('parses the current page from the query string', () {
        final page = extractCurrentPageFromUrl(
            'http://localhost:9000/?uri=x&page=inspector&theme=dark');
        expect(page, 'inspector');
      });

      test(
          'parses the current page from the path even if query string is populated',
          () {
        final page = extractCurrentPageFromUrl(
            'http://localhost:9000/memory?uri=x&page=inspector&theme=dark');
        expect(page, 'memory');
      });
    });
  });
}

const dartSdkUrl =
    'org-dartlang-sdk:///third_party/dart/sdk/lib/async/zone.dart';
const flutterUrl =
    'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart';
const flutterUrlFromNonFlutterDir =
    'file:///path/to/non-flutter/packages/flutter/lib/src/widgets/binding.dart';
