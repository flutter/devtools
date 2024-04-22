// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/test_data/extensions.dart';

void main() {
  group('$ExtensionService', () {
    // TODO(kenz): add tests for the ExtensionService class. Are the remaining
    // three covered well in integration tests?
    test('refresh', () {});

    test('_refreshExtensionEnabledStates', () {});

    test('setExtensionEnabledState', () {});

    group('handles duplicate extensions', () {
      late List<DevToolsExtensionConfig> runtimeExtensions;
      late List<DevToolsExtensionConfig> staticExtensions;
      final ignoredStaticExtensionsByHashCode = <int>{};

      void ignoreExtension(DevToolsExtensionConfig ext, [bool ignore = true]) {
        ignore
            ? ignoredStaticExtensionsByHashCode.add(identityHashCode(ext))
            : ignoredStaticExtensionsByHashCode.remove(identityHashCode(ext));
      }

      bool isExtensionIgnored(DevToolsExtensionConfig ext) {
        return ignoredStaticExtensionsByHashCode
            .contains(identityHashCode(ext));
      }

      setUp(() {
        ignoredStaticExtensionsByHashCode.clear();
        runtimeExtensions =
            testExtensions.where((e) => !e.detectedFromStaticContext).toList();
        staticExtensions =
            testExtensions.where((e) => e.detectedFromStaticContext).toList();
        expect(ignoredStaticExtensionsByHashCode, isEmpty);
      });

      test('maybeIgnoreExtensions when connected', () {
        ExtensionService.maybeIgnoreExtensions(
          connected: true,
          staticExtensions: staticExtensions,
          runtimeExtensions: runtimeExtensions,
          isIgnored: isExtensionIgnored,
          onIgnore: ignoreExtension,
        );
        expect(ignoredStaticExtensionsByHashCode.length, 2);
        // Ignored because there is a newer version available.
        expect(isExtensionIgnored(StubDevToolsExtensions.barExtension), true);
        // Ignored because this is a duplicate of a runtime extension.
        expect(
          isExtensionIgnored(StubDevToolsExtensions.duplicateFooExtension),
          true,
        );
      });

      test('maybeIgnoreExtensions when disconnected', () {
        ExtensionService.maybeIgnoreExtensions(
          connected: false,
          staticExtensions: staticExtensions,
          runtimeExtensions: [],
          isIgnored: isExtensionIgnored,
          onIgnore: ignoreExtension,
        );
        expect(ignoredStaticExtensionsByHashCode.length, 3);
        // Ignored because there is a newer version available.
        expect(isExtensionIgnored(StubDevToolsExtensions.barExtension), true);
        // Ignored because this extension requires a connected app, and we are
        // not connected.
        expect(isExtensionIgnored(StubDevToolsExtensions.bazExtension), true);
        // Ignored because this extension requires a connected app, and we are
        // not connected.
        expect(
          isExtensionIgnored(StubDevToolsExtensions.duplicateFooExtension),
          true,
        );
      });

      test('deduplicate static and runtime extensions', () {
        ExtensionService.deduplicateStaticExtensions(
          staticExtensions,
          onIgnore: ignoreExtension,
        );
        expect(ignoredStaticExtensionsByHashCode.length, 1);
        expect(isExtensionIgnored(StubDevToolsExtensions.barExtension), true);

        ExtensionService.deduplicateStaticExtensionsWithRuntimeExtensions(
          staticExtensions: staticExtensions,
          runtimeExtensions: runtimeExtensions,
          isIgnored: isExtensionIgnored,
          onIgnore: ignoreExtension,
        );
        expect(ignoredStaticExtensionsByHashCode.length, 2);
        expect(
          isExtensionIgnored(StubDevToolsExtensions.duplicateFooExtension),
          true,
        );
      });
    });

    test('ignore behavior', () {
      final extensionService = ExtensionService();
      final extensionsToIgnore = [
        StubDevToolsExtensions.barExtension,
        StubDevToolsExtensions.bazExtension,
        StubDevToolsExtensions.someToolExtension,
      ]..forEach(extensionService.ignoreExtension);
      for (final ext in StubDevToolsExtensions.extensions) {
        expect(
          extensionService.isExtensionIgnored(ext),
          extensionsToIgnore.contains(ext),
        );
      }
      for (final ext in extensionsToIgnore) {
        extensionService.ignoreExtension(ext, false);
      }
      for (final ext in StubDevToolsExtensions.extensions) {
        expect(extensionService.isExtensionIgnored(ext), false);
      }
    });

    test('takeLatestExtension returns newer extension', () {
      expect(
        takeLatestExtension(
          StubDevToolsExtensions.barExtension,
          StubDevToolsExtensions.newerBarExtension,
        ),
        StubDevToolsExtensions.newerBarExtension,
      );
    });

    test('takeLatestExtension handles parsing errors', () {
      // Returns 'b' when 'a' has parsing errors.
      var a = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: 'this-will-not-parse',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsUriKey: '/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey: '/path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      var b = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: '2.1.0',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsUriKey: '/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey: '/path/to/options/file',
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
        DevToolsExtensionConfig.extensionAssetsUriKey: '/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey: '/path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      b = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: 'this-will-not-parse',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsUriKey: '/path/to/bar',
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
        DevToolsExtensionConfig.extensionAssetsUriKey: '/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey: '/path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      b = DevToolsExtensionConfig.parse({
        DevToolsExtensionConfig.nameKey: 'bar',
        DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
        DevToolsExtensionConfig.versionKey: 'this-will-not-parse',
        DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
        DevToolsExtensionConfig.requiresConnectionKey: 'false',
        DevToolsExtensionConfig.extensionAssetsUriKey: '/path/to/bar',
        DevToolsExtensionConfig.devtoolsOptionsUriKey: '/path/to/options/file',
        DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
        DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
      });
      expect(takeLatestExtension(a, b), a);
    });
  });
}
