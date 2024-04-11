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
        'extensionAssetsUri': 'path/to/foo/extension',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': '0xf012',
        'isPubliclyHosted': 'false',
      });

      expect(config.name, 'foo');
      expect(config.extensionAssetsUri, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
    });

    test('parses with an int materialIconCodePoint field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'extensionAssetsUri': 'path/to/foo/extension',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': 0xf012,
        'isPubliclyHosted': 'false',
      });

      expect(config.name, 'foo');
      expect(config.extensionAssetsUri, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
    });

    test('parses with a null materialIconCodePoint field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'extensionAssetsUri': 'path/to/foo/extension',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'isPubliclyHosted': 'false',
      });

      expect(config.name, 'foo');
      expect(config.extensionAssetsUri, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf03f);
    });

    test('parse throws when missing a required field', () {
      Matcher throwsMissingRequiredFieldsError() {
        return throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'missing required fields StateError',
            startsWith('Missing required fields'),
          ),
        );
      }

      Matcher throwsMissingIsPubliclyHostedError() {
        return throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'missing isPubliclyHosted key StateError',
            startsWith('Missing key "isPubliclyHosted"'),
          ),
        );
      }

      // Missing 'name'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': 'false',
          });
        },
        throwsMissingRequiredFieldsError(),
      );

      // Missing 'issueTracker'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': 'false',
          });
        },
        throwsMissingRequiredFieldsError(),
      );

      // Missing 'version'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'issueTracker': 'www.google.com',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': 'false',
          });
        },
        throwsMissingRequiredFieldsError(),
      );

      // Missing 'materialIconCodePoint'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': 'false',
          });
        },
        throwsMissingRequiredFieldsError(),
      );

      // Missing 'extensionAssetsUri'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'isPubliclyHosted': 'false',
          });
        },
        throwsMissingRequiredFieldsError(),
      );

      // Missing 'isPubliclyHosted'.
      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
          });
        },
        throwsMissingIsPubliclyHostedError(),
      );
    });

    test('parse throws when value has unexpected type', () {
      Matcher throwsUnexpectedValueTypesError() {
        return throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'unexpected value types StateError',
            startsWith('Unexpected value types'),
          ),
        );
      }

      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 23,
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': 'false',
          });
        },
        throwsUnexpectedValueTypesError(),
      );

      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'foo',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': false,
          });
        },
        throwsUnexpectedValueTypesError(),
      );
    });

    test('parse throws for invalid name', () {
      Matcher throwsInvalidNameError() {
        return throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'unexpected value types StateError',
            startsWith('The "name" field in the extension config.yaml should'),
          ),
        );
      }

      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'name with spaces',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': 'false',
          });
        },
        throwsInvalidNameError(),
      );

      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'Name_With_Capital_Letters',
            'extensionAssetsUri': 'path/to/foo/extension',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'isPubliclyHosted': 'false',
          });
        },
        throwsInvalidNameError(),
      );

      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'name.with\'specialchars/',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'isPubliclyHosted': 'false',
          });
        },
        throwsInvalidNameError(),
      );
    });
  });
}
