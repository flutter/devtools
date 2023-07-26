// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('$DevToolsExtensionConfig', () {
    test('parses with a String materialIconCodePoint field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'path': 'path/to/foo/extension',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': '0xf012',
      });

      expect(config.name, 'foo');
      expect(config.path, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
    });

    test('parses with an int materialIconCodePoint field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'path': 'path/to/foo/extension',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': 0xf012,
      });

      expect(config.name, 'foo');
      expect(config.path, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
    });

    test('parses with a null materialIconCodePoint field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'path': 'path/to/foo/extension',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
      });

      expect(config.name, 'foo');
      expect(config.path, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf03f);
    });

    test('parse throws when missing a required field', () {
      // Missing 'name'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'path': 'path/to/foo/extension',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
          });
        },
        throwsA(isA<StateError>()),
      );

      // Missing 'path'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
          });
        },
        throwsA(isA<StateError>()),
      );

      // Missing 'issueTracker'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'path': 'path/to/foo/extension',
            'version': '1.0.0',
          });
        },
        throwsA(isA<StateError>()),
      );

      // Missing 'version'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'path': 'path/to/foo/extension',
            'issueTracker': 'www.google.com',
          });
        },
        throwsA(isA<StateError>()),
      );
    });
  });
}
