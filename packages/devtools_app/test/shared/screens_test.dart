// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/extensions/extension_screen.dart';
import 'package:devtools_app/src/framework/scaffold.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_app/src/shared/query_parameters.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenMetaData', () {
    test('values matches order of screens', () {
      final enumOrder = ScreenMetaData.values.map((s) => s.id).toList();
      final screenOrder =
          defaultScreens().map((screen) => screen.screen.screenId).toList();

      // Remove any items that don't exist in both - we can't verify
      // the order of those.
      enumOrder.removeWhereNot(screenOrder.toSet().contains);
      screenOrder.removeWhereNot(enumOrder.toSet().contains);

      expect(enumOrder, screenOrder);
    });
  });

  group('$DevToolsAppState', () {
    late Screen screen1;
    late Screen screen2;
    late Screen extensionScreen1;
    late Screen extensionScreen2;
    late List<Screen> screens;

    setUp(() {
      screen1 = SimpleScreen(const Placeholder());
      screen2 = SimpleScreen(const Placeholder());
      extensionScreen1 = DevToolsScreen<void>(
        ExtensionScreen(StubDevToolsExtensions.someToolExtension),
      ).screen;
      extensionScreen2 = DevToolsScreen<void>(
        ExtensionScreen(StubDevToolsExtensions.barExtension),
      ).screen;
      screens = <Screen>[
        screen1,
        screen2,
        extensionScreen1,
        extensionScreen2,
      ];
    });

    test(
      'hides extension screens based on query parameters',
      () {
        DevToolsAppState.removeHiddenScreens(
          screens,
          DevToolsQueryParams({
            DevToolsQueryParams.hideScreensKey:
                DevToolsQueryParams.hideExtensionsValue,
          }),
        );
        expect(screens.contains(screen1), true);
        expect(screens.contains(screen2), true);
        expect(screens.contains(extensionScreen1), false);
        expect(screens.contains(extensionScreen2), false);
      },
    );

    test(
      'hides all except extension screens based on query parameters',
      () {
        DevToolsAppState.removeHiddenScreens(
          screens,
          DevToolsQueryParams({
            DevToolsQueryParams.hideScreensKey:
                DevToolsQueryParams.hideAllExceptExtensionsValue,
          }),
        );
        expect(screens.contains(screen1), false);
        expect(screens.contains(screen2), false);
        expect(screens.contains(extensionScreen1), true);
        expect(screens.contains(extensionScreen2), true);
      },
    );

    test('maybeIncludeOnlyEmbeddedScreen', () {
      expect(
        DevToolsAppState.maybeIncludeOnlyEmbeddedScreen(
          screen1,
          page: ScreenMetaData.simple.id,
          embedMode: EmbedMode.embedOne,
        ),
        true,
      );
      expect(
        DevToolsAppState.maybeIncludeOnlyEmbeddedScreen(
          extensionScreen1, // Ids do not match.
          page: ScreenMetaData.simple.id,
          embedMode: EmbedMode.embedOne,
        ),
        false,
      );
      // Should always return true when 'embedMode' != EmbedMode.embedOne
      expect(
        DevToolsAppState.maybeIncludeOnlyEmbeddedScreen(
          extensionScreen1, // Ids do not match.
          page: ScreenMetaData.simple.id,
          embedMode: EmbedMode.embedMany,
        ),
        true,
      );
      expect(
        DevToolsAppState.maybeIncludeOnlyEmbeddedScreen(
          extensionScreen1, // Ids do not match.
          page: ScreenMetaData.simple.id,
          embedMode: EmbedMode.none,
        ),
        true,
      );
    });
  });
}

extension _ListExtension<T> on List<T> {
  void removeWhereNot(bool Function(T) test) {
    removeWhere((item) => !test(item));
  }
}
