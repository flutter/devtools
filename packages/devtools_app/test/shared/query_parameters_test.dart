// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:devtools_app/src/shared/query_parameters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$DevToolsQueryParams', () {
    test('creates empty params', () {
      final params = DevToolsQueryParams.empty();
      expect(params.vmServiceUri, isNull);
      expect(params.embed, isFalse);
      expect(params.hiddenScreens, isEmpty);
      expect(params.offlineScreenId, isNull);
      expect(params.legacyPage, isNull);
      expect(params.ideThemeParams.params, isEmpty);
    });

    test('successfully creates params', () {
      final params = DevToolsQueryParams({
        DevToolsQueryParams.vmServiceUriKey: 'some_uri',
        DevToolsQueryParams.hideScreensKey: 'foo,bar,baz',
        DevToolsQueryParams.offlineScreenIdKey: 'performance',
        DevToolsQueryParams.legacyPageKey: 'memory',
        // IdeThemeQueryParams values
        'embed': 'true',
        'backgroundColor': '#112233',
        'foregroundColor': '#112244',
        'fontSize': '8.0',
        'theme': 'dark',
      });

      expect(params.vmServiceUri, 'some_uri');
      expect(params.embed, true);
      expect(params.hiddenScreens, {'foo', 'bar', 'baz'});
      expect(params.offlineScreenId, 'performance');
      expect(params.legacyPage, 'memory');
      expect(params.ideThemeParams.params, isNotEmpty);
      expect(params.ideThemeParams.embed, true);
      expect(params.ideThemeParams.backgroundColor, const Color(0xFF112233));
      expect(params.ideThemeParams.foregroundColor, const Color(0xFF112244));
      expect(params.ideThemeParams.fontSize, 8.0);
      expect(params.ideThemeParams.darkMode, true);
    });
  });
}
