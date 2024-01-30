// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/extensions/embedded/view.dart';
import 'package:devtools_app/src/extensions/extension_screen.dart';
import 'package:devtools_app/src/extensions/extension_screen_controls.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/test_data/extensions.dart';

void main() {
  const windowSize = Size(2000.0, 2000.0);
  group('$ExtensionScreen', () {
    late ExtensionScreen fooScreen;
    late ExtensionScreen barScreen;
    late ExtensionScreen providerScreen;

    setUp(() async {
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
      fooScreen = ExtensionScreen(fooExtension);
      barScreen = ExtensionScreen(barExtension);
      providerScreen = ExtensionScreen(providerExtension);

      setGlobal(
        ExtensionService,
        await createMockExtensionServiceWithDefaults(testExtensions),
      );
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: fooScreen.buildTab)));
      expect(find.text('foo'), findsOneWidget);
      expect(find.byIcon(fooExtension.icon), findsOneWidget);

      await tester.pumpWidget(wrap(Builder(builder: barScreen.buildTab)));
      expect(find.text('bar'), findsOneWidget);
      expect(find.byIcon(barExtension.icon), findsOneWidget);

      await tester.pumpWidget(wrap(Builder(builder: providerScreen.buildTab)));
      expect(find.text('provider'), findsOneWidget);
      expect(find.byIcon(providerExtension.icon), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'renders for unactivated state',
      windowSize,
      (tester) async {
        await tester.pumpWidget(wrap(Builder(builder: fooScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:foo extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v1.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        expect(_extensionContextMenuFinder, findsNothing);
        expect(find.byType(EnableExtensionPrompt), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsNothing);

        await tester.pumpWidget(wrap(Builder(builder: barScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:bar extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v2.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        expect(_extensionContextMenuFinder, findsNothing);
        expect(find.byType(EnableExtensionPrompt), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsNothing);

        await tester.pumpWidget(wrap(Builder(builder: providerScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:provider extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v3.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        expect(_extensionContextMenuFinder, findsNothing);
        expect(find.byType(EnableExtensionPrompt), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'renders for enabled state',
      windowSize,
      (tester) async {
        await extensionService.setExtensionEnabledState(
          fooExtension,
          enable: true,
        );

        await tester.pumpWidget(wrap(Builder(builder: fooScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:foo extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v1.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        await _verifyContextMenuContents(tester);
        expect(find.byType(EnableExtensionPrompt), findsNothing);
        expect(find.byType(EmbeddedExtensionView), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'renders for disabled state',
      windowSize,
      (tester) async {
        await extensionService.setExtensionEnabledState(
          fooExtension,
          enable: false,
        );

        await tester.pumpWidget(wrap(Builder(builder: fooScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:foo extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v1.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        expect(_extensionContextMenuFinder, findsNothing);
        expect(find.byType(EnableExtensionPrompt), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'can enable and disable extension from screen',
      windowSize,
      (tester) async {
        await tester.pumpWidget(wrap(Builder(builder: fooScreen.build)));

        expect(
          extensionService.enabledStateListenable(fooExtension.name).value,
          ExtensionEnabledState.none,
        );
        expect(find.byType(EnableExtensionPrompt), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsNothing);
        expect(_extensionContextMenuFinder, findsNothing);

        await tester.tap(
          find.descendant(
            of: find.byType(GaDevToolsButton),
            matching: find.text('Enable'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          extensionService.enabledStateListenable(fooExtension.name).value,
          ExtensionEnabledState.enabled,
        );
        expect(find.byType(EnableExtensionPrompt), findsNothing);
        expect(find.byType(EmbeddedExtensionView), findsOneWidget);
        await _verifyContextMenuContents(
          tester,
          autoDismiss: false,
        );

        await tester.tap(find.text('Disable extension'));
        await tester.pumpAndSettle();

        expect(find.byType(DisableExtensionDialog), findsOneWidget);

        await tester.tap(find.text('YES, DISABLE'));
        await tester.pumpAndSettle();

        expect(
          extensionService.enabledStateListenable(fooExtension.name).value,
          ExtensionEnabledState.disabled,
        );
        expect(find.byType(EnableExtensionPrompt), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsNothing);
        expect(_extensionContextMenuFinder, findsNothing);
      },
    );
  });
}

Future<void> _verifyContextMenuContents(
  WidgetTester tester, {
  bool autoDismiss = true,
}) async {
  expect(_extensionContextMenuFinder, findsOneWidget);
  await tester.tap(_extensionContextMenuFinder);
  await tester.pumpAndSettle();
  expect(find.text('Disable extension'), findsOneWidget);
  expect(find.text('Force reload extension'), findsOneWidget);
  if (autoDismiss) {
    // Tap the context menu again to dismiss it.
    await tester.tap(_extensionContextMenuFinder);
    await tester.pumpAndSettle();
  }
}

Finder get _extensionContextMenuFinder => find.descendant(
      of: find.byType(EmbeddedExtensionHeader),
      matching: find.byType(ContextMenuButton),
    );
