// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
}
