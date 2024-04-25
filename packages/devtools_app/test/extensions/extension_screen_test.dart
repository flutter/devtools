// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/extensions/embedded/view.dart';
import 'package:devtools_app/src/extensions/extension_screen.dart';
import 'package:devtools_app/src/extensions/extension_screen_controls.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const windowSize = Size(2000.0, 2000.0);
  group('$ExtensionScreen', () {
    late ExtensionScreen fooScreen;
    late ExtensionScreen barScreen;
    late ExtensionScreen providerScreen;

    setUp(() async {
      setTestMode();
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
      setGlobal(OfflineDataController, OfflineDataController());
      fooScreen = ExtensionScreen(StubDevToolsExtensions.fooExtension);
      barScreen = ExtensionScreen(StubDevToolsExtensions.barExtension);
      providerScreen =
          ExtensionScreen(StubDevToolsExtensions.providerExtension);

      setGlobal(
        ExtensionService,
        ExtensionService(
          fixedAppRoot: Uri.parse('file:///Users/me/package_root_1'),
        ),
      );
      await extensionService.initialize();
      expect(extensionService.staticExtensions.length, 4);
      expect(extensionService.runtimeExtensions.length, 3);
      expect(extensionService.availableExtensions.value.length, 5);
    });

    tearDown(() {
      resetDevToolsExtensionEnabledStates();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: fooScreen.buildTab)));
      expect(find.text('foo'), findsOneWidget);
      expect(
        find.byIcon(StubDevToolsExtensions.fooExtension.icon),
        findsOneWidget,
      );

      await tester.pumpWidget(wrap(Builder(builder: barScreen.buildTab)));
      expect(find.text('bar'), findsOneWidget);
      expect(
        find.byIcon(StubDevToolsExtensions.barExtension.icon),
        findsOneWidget,
      );

      await tester.pumpWidget(wrap(Builder(builder: providerScreen.buildTab)));
      expect(find.text('provider'), findsOneWidget);
      expect(
        find.byIcon(StubDevToolsExtensions.providerExtension.icon),
        findsOneWidget,
      );
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
          StubDevToolsExtensions.fooExtension,
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
          StubDevToolsExtensions.fooExtension,
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
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.fooExtension.name)
              .value,
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
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.fooExtension.name)
              .value,
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
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.fooExtension.name)
              .value,
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
