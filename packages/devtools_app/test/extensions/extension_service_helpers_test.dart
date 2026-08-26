// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('takeLatestExtension', () {
    test('returns newer extension', () {
      expect(
        takeLatestExtension(
          StubDevToolsExtensions.barExtension,
          StubDevToolsExtensions.newerBarExtension,
        ),
        StubDevToolsExtensions.newerBarExtension,
      );
    });

    test('handles parsing errors', () {
      // Returns 'b' when 'a' has parsing errors.
      var a = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: 'this-will-not-parse',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      var b = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: '2.1.0',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      expect(takeLatestExtension(a, b), b);

      // Returns 'a' when 'b' has parsing errors.
      a = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: '2.1.0',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      b = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: 'this-will-not-parse',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey: '/path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      expect(takeLatestExtension(a, b), a);

      // Returns 'a' when both 'a' and 'b' have parsing errors.
      a = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: 'this-will-not-parse',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      b = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: 'this-will-not-parse',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      expect(takeLatestExtension(a, b), a);
    });
  });

  group('deduplicateExtensionsAndTakeLatest', () {
    test('deduplicates matching packageName and name', () {
      final ignored = <DevToolsExtensionConfig>{};
      final ext1 = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'provider',
        DevToolsExtensionConfig.packageNameKey: 'provider',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: '1.0.0',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/path/to/provider_1',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      final ext2 = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'provider',
        DevToolsExtensionConfig.packageNameKey: 'provider',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: '2.0.0',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/path/to/provider_2',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });

      deduplicateExtensionsAndTakeLatest(
        [ext1, ext2],
        onSetIgnored: (ext, {required ignore}) {
          if (ignore) {
            ignored.add(ext);
          } else {
            ignored.remove(ext);
          }
        },
      );

      expect(ignored, contains(ext1));
      expect(ignored, isNot(contains(ext2)));
    });

    test('does not deduplicate across different packageNames', () {
      final ignored = <DevToolsExtensionConfig>{};
      final providerExt = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'provider',
        DevToolsExtensionConfig.packageNameKey: 'provider',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: '1.0.0',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/path/to/provider',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      final spoofedExt = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'provider',
        DevToolsExtensionConfig.packageNameKey: 'bad_pkg',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: '999.0.0',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsPathKey: '/path/to/bad_pkg',
        DevToolsExtensionConfig.devtoolsOptionsUriKey:
            'file:///path/to/options',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });

      deduplicateExtensionsAndTakeLatest(
        [providerExt, spoofedExt],
        onSetIgnored: (ext, {required ignore}) {
          if (ignore) {
            ignored.add(ext);
          } else {
            ignored.remove(ext);
          }
        },
      );

      // Neither should be ignored because they come from different packages.
      expect(ignored, isEmpty);
    });
  });
}
