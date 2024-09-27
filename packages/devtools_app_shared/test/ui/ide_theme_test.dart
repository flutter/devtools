// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
        'fontSize': '8.0',
        'theme': 'dark',
      });

      expect(params.params, isNotEmpty);
      expect(params.embedMode, EmbedMode.embedOne);
      expect(params.backgroundColor, const Color(0xFF112233));
      expect(params.foregroundColor, const Color(0xFF112244));
      expect(params.fontSize, 8.0);
      expect(params.darkMode, true);
    });

    test('handles bad input', () {
      final params = IdeThemeQueryParams({
        'embedMode': 'blah',
        'backgroundColor': 'badcolor',
        'foregroundColor': 'badcolor',
        'fontSize': 'eight',
        'theme': 'dark',
      });

      expect(params.params, isNotEmpty);
      expect(params.embedMode, EmbedMode.none);
      expect(params.backgroundColor, isNull);
      expect(params.foregroundColor, isNull);
      expect(params.fontSize, unscaledDefaultFontSize);
      expect(params.darkMode, true);
    });

    test('creates empty params', () {
      final params = IdeThemeQueryParams({});
      expect(params.params, isEmpty);
      expect(params.embedMode, EmbedMode.none);
      expect(params.backgroundColor, isNull);
      expect(params.foregroundColor, isNull);
      expect(params.fontSize, unscaledDefaultFontSize);
      expect(params.darkMode, true);
    });
  });
}
