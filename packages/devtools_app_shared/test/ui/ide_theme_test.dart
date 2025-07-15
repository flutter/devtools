// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:ui';

import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$IdeThemeQueryParams', () {
    test('successfully creates params', () {
      final params = IdeThemeQueryParams({
        'embedMode': 'one',
        'backgroundColor': '#112233',
        'foregroundColor': '#112244',
        'theme': 'dark',
      });

      expect(params.params, isNotEmpty);
      expect(params.embedMode, EmbedMode.embedOne);
      expect(params.backgroundColor, const Color(0xFF112233));
      expect(params.foregroundColor, const Color(0xFF112244));
      expect(params.darkMode, true);
    });

    test('handles bad input', () {
      final params = IdeThemeQueryParams({
        'embedMode': 'blah',
        'backgroundColor': 'badcolor',
        'foregroundColor': 'badcolor',
        'theme': 'dark',
      });

      expect(params.params, isNotEmpty);
      expect(params.embedMode, EmbedMode.none);
      expect(params.backgroundColor, isNull);
      expect(params.foregroundColor, isNull);
      expect(params.darkMode, true);
    });

    test('ignores unsupported query params', () {
      final params = IdeThemeQueryParams({
        'fontSize': '50', // Font size is not supported.
        'theme': 'dark',
      });

      expect(params.darkMode, true);
    });

    test('creates empty params', () {
      final params = IdeThemeQueryParams({});
      expect(params.params, isEmpty);
      expect(params.embedMode, EmbedMode.none);
      expect(params.backgroundColor, isNull);
      expect(params.foregroundColor, isNull);
      expect(params.darkMode, true);
    });
  });
}
