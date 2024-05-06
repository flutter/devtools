// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:devtools_app/src/shared/query_parameters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$DevToolsQueryParams', () {
    test('successfully creates params', () {
      final params = DevToolsQueryParams({
        DevToolsQueryParams.vmServiceUriKey: 'some_uri',
        DevToolsQueryParams.hideScreensKey: 'foo,bar,extensions',
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
      expect(params.hideExtensions, true);
      expect(params.offlineScreenId, 'performance');
      expect(params.legacyPage, 'memory');
      expect(params.ideThemeParams.params, isNotEmpty);
      expect(params.ideThemeParams.embed, true);
      expect(params.ideThemeParams.backgroundColor, const Color(0xFF112233));
      expect(params.ideThemeParams.foregroundColor, const Color(0xFF112244));
      expect(params.ideThemeParams.fontSize, 8.0);
      expect(params.ideThemeParams.darkMode, true);
    });

    test('creates empty params', () {
      final params = DevToolsQueryParams.empty();
      expect(params.vmServiceUri, isNull);
      expect(params.embed, isFalse);
      expect(params.hiddenScreens, isEmpty);
      expect(params.offlineScreenId, isNull);
      expect(params.legacyPage, isNull);
      expect(params.ideThemeParams.params, isEmpty);
    });

    test('creates params with updates', () {
      var params = DevToolsQueryParams({
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

      params = params.withUpdates({
        DevToolsQueryParams.vmServiceUriKey: 'some_other_uri',
        DevToolsQueryParams.hideScreensKey: 'foo',
        // Update some IdeThemeQueryParams values
        'embed': 'false',
        'fontSize': '10.0',
        'theme': 'light',
      });

      expect(params.vmServiceUri, 'some_other_uri');
      expect(params.embed, false);
      expect(params.hiddenScreens, {'foo'});
      expect(params.offlineScreenId, 'performance');
      expect(params.legacyPage, 'memory');
      expect(params.ideThemeParams.params, isNotEmpty);
      expect(params.ideThemeParams.embed, false);
      expect(params.ideThemeParams.backgroundColor, const Color(0xFF112233));
      expect(params.ideThemeParams.foregroundColor, const Color(0xFF112244));
      expect(params.ideThemeParams.fontSize, 10.0);
      expect(params.ideThemeParams.darkMode, false);
    });
  });
}
