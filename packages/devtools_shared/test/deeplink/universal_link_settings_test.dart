// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:devtools_shared/src/deeplink/universal_link_settings.dart';
import 'package:test/test.dart';

void main() {
  group('UniversalLinkSettings', () {
    test('parses json correctly', () {
      const json = '''
{
  "bundleIdentifier": "com.example.app",
  "teamIdentifier": "TEAMID",
  "associatedDomains": ["applinks:example.com"]
}
''';
      final settings = UniversalLinkSettings.fromJson(json);
      expect(settings.bundleIdentifier, 'com.example.app');
      expect(settings.teamIdentifier, 'TEAMID');
      expect(settings.associatedDomains, ['applinks:example.com']);
    });

    test('handles null bundleIdentifier', () {
      const json = '''
{
  "teamIdentifier": "TEAMID",
  "associatedDomains": ["applinks:example.com"]
}
''';
      final settings = UniversalLinkSettings.fromJson(json);
      expect(settings.bundleIdentifier, isNull);
      expect(settings.teamIdentifier, 'TEAMID');
      expect(settings.associatedDomains, ['applinks:example.com']);
    });

    test('handles null teamIdentifier', () {
      const json = '''
{
  "bundleIdentifier": "com.example.app",
  "associatedDomains": ["applinks:example.com"]
}
''';
      final settings = UniversalLinkSettings.fromJson(json);
      expect(settings.bundleIdentifier, 'com.example.app');
      expect(settings.teamIdentifier, isNull);
      expect(settings.associatedDomains, ['applinks:example.com']);
    });
  });
}
