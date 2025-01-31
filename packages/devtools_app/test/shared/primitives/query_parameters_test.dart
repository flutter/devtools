// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:ui';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/primitives/query_parameters.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$DevToolsQueryParams', () {
    test('successfully creates params', () {
      final params = DevToolsQueryParams({
        DevToolsQueryParams.vmServiceUriKey: 'some_uri',
        DevToolsQueryParams.hideScreensKey:
            'foo,bar,extensions,all-except-extensions',
        DevToolsQueryParams.offlineScreenIdKey: 'performance',
        DevToolsQueryParams.inspectorRefKey: '12345',
        AppSizeApi.baseAppSizeFilePropertyName: '/path/to/base/file.json',
        AppSizeApi.testAppSizeFilePropertyName: '/path/to/test/file.json',
        DevToolsQueryParams.ideKey: 'Android-Studio',
        DevToolsQueryParams.ideFeatureKey: 'onDebugAutomatic',
        DevToolsQueryParams.legacyPageKey: 'memory',
        // IdeThemeQueryParams values
        'embedMode': 'one',
        IdeThemeQueryParams.backgroundColorKey: '#112233',
        IdeThemeQueryParams.foregroundColorKey: '#112244',
        IdeThemeQueryParams.fontSizeKey: '8.0',
        IdeThemeQueryParams.devToolsThemeKey: 'dark',
      });

      expect(params.vmServiceUri, 'some_uri');
      expect(params.hiddenScreens, {
        'foo',
        'bar',
        'extensions',
        'all-except-extensions',
      });
      expect(params.hideExtensions, true);
      expect(params.hideAllExceptExtensions, true);
      expect(params.offlineScreenId, 'performance');
      expect(params.inspectorRef, '12345');
      expect(params.appSizeBaseFilePath, '/path/to/base/file.json');
      expect(params.appSizeTestFilePath, '/path/to/test/file.json');
      expect(params.ide, 'Android-Studio');
      expect(params.ideFeature, 'onDebugAutomatic');
      expect(params.legacyPage, 'memory');
      expect(params.ideThemeParams.params, isNotEmpty);
      expect(params.embedMode, EmbedMode.embedOne);
      expect(params.ideThemeParams.embedMode, EmbedMode.embedOne);
      expect(params.ideThemeParams.backgroundColor, const Color(0xFF112233));
      expect(params.ideThemeParams.foregroundColor, const Color(0xFF112244));
      expect(params.ideThemeParams.fontSize, 8.0);
      expect(params.ideThemeParams.darkMode, true);
    });

    test('creates empty params', () {
      final params = DevToolsQueryParams.empty();
      expect(params.vmServiceUri, isNull);
      expect(params.hiddenScreens, isEmpty);
      expect(params.hideExtensions, false);
      expect(params.hideAllExceptExtensions, false);
      expect(params.offlineScreenId, isNull);
      expect(params.inspectorRef, isNull);
      expect(params.appSizeBaseFilePath, isNull);
      expect(params.appSizeTestFilePath, isNull);
      expect(params.ide, isNull);
      expect(params.ideFeature, isNull);
      expect(params.legacyPage, isNull);
      expect(params.ideThemeParams.params, isEmpty);
      expect(params.embedMode, EmbedMode.none);
    });

    test('creates params with updates', () {
      var params = DevToolsQueryParams({
        DevToolsQueryParams.vmServiceUriKey: 'some_uri',
        DevToolsQueryParams.hideScreensKey: 'foo,bar,baz',
        DevToolsQueryParams.offlineScreenIdKey: 'performance',
        DevToolsQueryParams.inspectorRefKey: '12345',
        AppSizeApi.baseAppSizeFilePropertyName: '/path/to/base/file.json',
        AppSizeApi.testAppSizeFilePropertyName: '/path/to/test/file.json',
        DevToolsQueryParams.ideKey: 'Android-Studio',
        DevToolsQueryParams.ideFeatureKey: 'onDebugAutomatic',
        DevToolsQueryParams.legacyPageKey: 'memory',
        // IdeThemeQueryParams values
        'embedMode': 'one',
        IdeThemeQueryParams.backgroundColorKey: '#112233',
        IdeThemeQueryParams.foregroundColorKey: '#112244',
        IdeThemeQueryParams.fontSizeKey: '8.0',
        IdeThemeQueryParams.devToolsThemeKey: 'dark',
      });

      expect(params.vmServiceUri, 'some_uri');
      expect(params.hiddenScreens, {'foo', 'bar', 'baz'});
      expect(params.offlineScreenId, 'performance');
      expect(params.inspectorRef, '12345');
      expect(params.appSizeBaseFilePath, '/path/to/base/file.json');
      expect(params.appSizeTestFilePath, '/path/to/test/file.json');
      expect(params.ide, 'Android-Studio');
      expect(params.ideFeature, 'onDebugAutomatic');
      expect(params.legacyPage, 'memory');
      expect(params.ideThemeParams.params, isNotEmpty);
      expect(params.embedMode, EmbedMode.embedOne);
      expect(params.ideThemeParams.embedMode, EmbedMode.embedOne);
      expect(params.ideThemeParams.backgroundColor, const Color(0xFF112233));
      expect(params.ideThemeParams.foregroundColor, const Color(0xFF112244));
      expect(params.ideThemeParams.fontSize, 8.0);
      expect(params.ideThemeParams.darkMode, true);

      params = params.withUpdates({
        DevToolsQueryParams.vmServiceUriKey: 'some_other_uri',
        DevToolsQueryParams.hideScreensKey: 'foo',
        DevToolsQueryParams.inspectorRefKey: '23456',
        // Update some IdeThemeQueryParams values
        'embedMode': 'many',
        'fontSize': '10.0',
        'theme': 'light',
      });

      expect(params.vmServiceUri, 'some_other_uri');
      expect(params.hiddenScreens, {'foo'});
      expect(params.offlineScreenId, 'performance');
      expect(params.inspectorRef, '23456');
      expect(params.appSizeBaseFilePath, '/path/to/base/file.json');
      expect(params.appSizeTestFilePath, '/path/to/test/file.json');
      expect(params.ide, 'Android-Studio');
      expect(params.ideFeature, 'onDebugAutomatic');
      expect(params.legacyPage, 'memory');
      expect(params.ideThemeParams.params, isNotEmpty);
      expect(params.embedMode, EmbedMode.embedMany);
      expect(params.ideThemeParams.embedMode, EmbedMode.embedMany);
      expect(params.ideThemeParams.backgroundColor, const Color(0xFF112233));
      expect(params.ideThemeParams.foregroundColor, const Color(0xFF112244));
      expect(params.ideThemeParams.fontSize, 10.0);
      expect(params.ideThemeParams.darkMode, false);
    });

    test('creates fromUrl', () {
      expect(
        DevToolsQueryParams.fromUrl(
          'http://localhost:123/?key=value.json&key2=123',
        ),
        equals({'key': 'value.json', 'key2': '123'}),
      );
      expect(
        DevToolsQueryParams.fromUrl(
          'http://localhost:123/?key=value.json&key2=123',
        ),
        equals({'key': 'value.json', 'key2': '123'}),
      );
      for (final meta in ScreenMetaData.values) {
        expect(
          DevToolsQueryParams.fromUrl(
            'http://localhost:9101/${meta.id}?key=value.json&key2=123',
          ),
          equals({'key': 'value.json', 'key2': '123'}),
        );
      }
    });
  });
}
