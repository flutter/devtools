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
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': '0xf012',
        // requiresConnection field can be omitted because it is optional.
        'extensionAssetsUri': 'path/to/foo/extension',
        'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
        'isPubliclyHosted': 'false',
        'detectedFromStaticContext': 'false',
      });

      expect(config.name, 'foo');
      expect(config.extensionAssetsUri, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
      expect(config.requiresConnection, true);
    });

    test('parses with an int materialIconCodePoint field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': 0xf012,
        'requiresConnection': 'true',
        'extensionAssetsUri': 'path/to/foo/extension',
        'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
        'isPubliclyHosted': 'false',
        'detectedFromStaticContext': 'false',
      });

      expect(config.name, 'foo');
      expect(config.extensionAssetsUri, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
      expect(config.requiresConnection, true);
    });

    test('parses with a String requiresConnection field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': '0xf012',
        'requiresConnection': 'false',
        'extensionAssetsUri': 'path/to/foo/extension',
        'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
        'isPubliclyHosted': 'false',
        'detectedFromStaticContext': 'false',
      });

      expect(config.name, 'foo');
      expect(config.extensionAssetsUri, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
      expect(config.requiresConnection, false);
    });

    test('parses with a bool requiresConnection field', () {
      final config = DevToolsExtensionConfig.parse({
        'name': 'foo',
        'issueTracker': 'www.google.com',
        'version': '1.0.0',
        'materialIconCodePoint': 0xf012,
        'requiresConnection': false,
        'extensionAssetsUri': 'path/to/foo/extension',
        'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
        'isPubliclyHosted': 'false',
        'detectedFromStaticContext': 'false',
      });

      expect(config.name, 'foo');
      expect(config.extensionAssetsUri, 'path/to/foo/extension');
      expect(config.issueTrackerLink, 'www.google.com');
      expect(config.version, '1.0.0');
      expect(config.materialIconCodePoint, 0xf012);
      expect(config.requiresConnection, false);
    });

    group('parse throws when missing required field', () {
      Matcher throwsMissingRequiredFieldsError() {
        return throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'missing required fields StateError',
            startsWith('Missing required fields'),
          ),
        );
      }

      Matcher throwsMissingGeneratedKeysError() {
        return throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'Missing generated keys StateError',
            startsWith('Missing generated keys'),
          ),
        );
      }

      test('name', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'issueTracker': 'www.google.com',
              'version': '1.0.0',
              'materialIconCodePoint': 0xf012,
              'extensionAssetsUri': 'path/to/foo/extension',
              'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
              'isPubliclyHosted': 'false',
              'detectedFromStaticContext': 'false',
            });
          },
          throwsMissingRequiredFieldsError(),
        );
      });

      test('issueTracker', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'name': 'foo',
              'version': '1.0.0',
              'materialIconCodePoint': 0xf012,
              'extensionAssetsUri': 'path/to/foo/extension',
              'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
              'isPubliclyHosted': 'false',
              'detectedFromStaticContext': 'false',
            });
          },
          throwsMissingRequiredFieldsError(),
        );
      });

      test('version', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'name': 'foo',
              'issueTracker': 'www.google.com',
              'materialIconCodePoint': 0xf012,
              'extensionAssetsUri': 'path/to/foo/extension',
              'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
              'isPubliclyHosted': 'false',
              'detectedFromStaticContext': 'false',
            });
          },
          throwsMissingRequiredFieldsError(),
        );
      });

      test('materialIconCodePoint', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'name': 'foo',
              'issueTracker': 'www.google.com',
              'version': '1.0.0',
              'extensionAssetsUri': 'path/to/foo/extension',
              'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
              'isPubliclyHosted': 'false',
              'detectedFromStaticContext': 'false',
            });
          },
          throwsMissingRequiredFieldsError(),
        );
      });
      test('extensionAssetsUri', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'name': 'foo',
              'issueTracker': 'www.google.com',
              'version': '1.0.0',
              'materialIconCodePoint': 0xf012,
              'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
              'isPubliclyHosted': 'false',
              'detectedFromStaticContext': 'false',
            });
          },
          throwsMissingGeneratedKeysError(),
        );
      });

      test('devtoolsOptionsUri', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'name': 'foo',
              'issueTracker': 'www.google.com',
              'version': '1.0.0',
              'materialIconCodePoint': 0xf012,
              'extensionAssetsUri': 'path/to/foo/extension',
              'isPubliclyHosted': 'false',
              'detectedFromStaticContext': 'false',
            });
          },
          throwsMissingGeneratedKeysError(),
        );
      });

      test('isPubliclyHosted', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'name': 'foo',
              'issueTracker': 'www.google.com',
              'version': '1.0.0',
              'materialIconCodePoint': 0xf012,
              'extensionAssetsUri': 'path/to/foo/extension',
              'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
              'detectedFromStaticContext': 'false',
            });
          },
          throwsMissingGeneratedKeysError(),
        );
      });

      test('detectedFromStaticContext', () {
        expect(
          () {
            DevToolsExtensionConfig.parse({
              'name': 'foo',
              'issueTracker': 'www.google.com',
              'version': '1.0.0',
              'materialIconCodePoint': 0xf012,
              'extensionAssetsUri': 'path/to/foo/extension',
              'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
              'isPubliclyHosted': 'false',
            });
          },
          throwsMissingGeneratedKeysError(),
        );
      });
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
            // Expects a String here.
            'name': 23,
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
            'isPubliclyHosted': 'false',
            'detectedFromStaticContext': 'false',
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
            'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
            // Expects a String here.
            'isPubliclyHosted': false,
            'detectedFromStaticContext': 'false',
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
            'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
            'isPubliclyHosted': 'false',
            'detectedFromStaticContext': 'false',
          });
        },
        throwsInvalidNameError(),
      );

      expect(
        () {
          DevToolsExtensionConfig.parse({
            'name': 'Name_With_Capital_Letters',
            'issueTracker': 'www.google.com',
            'version': '1.0.0',
            'materialIconCodePoint': 0xf012,
            'extensionAssetsUri': 'path/to/foo/extension',
            'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
            'isPubliclyHosted': 'false',
            'detectedFromStaticContext': 'false',
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
            'devtoolsOptionsUri': 'path/to/package/devtools_options.yaml',
            'isPubliclyHosted': 'false',
            'detectedFromStaticContext': 'false',
          });
        },
        throwsInvalidNameError(),
      );
    });
  });
}
