// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/extensions/embedded/view.dart';
import 'package:devtools_app/src/extensions/extension_screen.dart';
import 'package:devtools_app/src/extensions/extension_screen_controls.dart';
import 'package:devtools_app/src/extensions/extension_settings.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/devtools_extensions_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() {
    resetDevToolsExtensionEnabledStates();
  });

  testWidgets('end to end extensions flow', (tester) async {
    await pumpAndConnectDevTools(tester, testApp);
    resetDevToolsExtensionEnabledStates();

    expect(extensionService.availableExtensions.value.length, 7);
    expect(extensionService.visibleExtensions.value.length, 7);
    await _verifyExtensionsSettingsMenu(
      tester,
      [
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
      ],
      closeMenuWhenDone: false,
    );

    await _verifyExtensionVisibilitySetting(tester);

    // Bar extension.
    // Enable, test context menu actions, then disable from context menu.
    await _switchToExtensionScreen(
      tester,
      extensionIndex: 0,
      initialLoad: true,
    );
    await _answerEnableExtensionPrompt(tester, enable: true);
    await _verifyExtensionsSettingsMenu(
      tester,
      [
        ExtensionEnabledState.enabled,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
      ],
    );

    await _verifyContextMenuActions(tester);

    expect(extensionService.availableExtensions.value.length, 7);
    expect(extensionService.visibleExtensions.value.length, 6);
    await _verifyExtensionTabVisibility(
      tester,
      extensionIndex: 0,
      visible: false,
    );
    await _verifyExtensionsSettingsMenu(
      tester,
      [
        ExtensionEnabledState.disabled,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
      ],
    );

    // Foo extension. Hide immediately, then re-enable from extensions menu.
    await _switchToExtensionScreen(
      tester,
      extensionIndex: 1,
      initialLoad: true,
    );
    await _answerEnableExtensionPrompt(tester, enable: false);

    expect(extensionService.availableExtensions.value.length, 7);
    expect(extensionService.visibleExtensions.value.length, 5);
    await _verifyExtensionTabVisibility(
      tester,
      extensionIndex: 1,
      visible: false,
    );
    await _verifyExtensionsSettingsMenu(
      tester,
      [
        ExtensionEnabledState.disabled,
        ExtensionEnabledState.disabled,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
      ],
    );

    logStatus('verify we can re-enable an extension from the settings menu');
    await _changeExtensionSetting(tester, extensionIndex: 1, enable: true);

    expect(extensionService.availableExtensions.value.length, 7);
    expect(extensionService.visibleExtensions.value.length, 6);
    await _switchToExtensionScreen(tester, extensionIndex: 1);
    expect(find.byType(EnableExtensionPrompt), findsNothing);
    expect(find.byType(EmbeddedExtensionView), findsOneWidget);
    expect(find.byType(HtmlElementView), findsOneWidget);
    await _verifyExtensionsSettingsMenu(
      tester,
      [
        ExtensionEnabledState.disabled,
        ExtensionEnabledState.enabled,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
      ],
    );

    // Provider extension. Disable directly from settings menu.
    logStatus(
      'verify we can disable an extension screen directly from the settings menu',
    );
    await _verifyExtensionTabVisibility(
      tester,
      extensionIndex: 2,
      visible: true,
    );

    logStatus('disable the extension from the settings menu');
    await _changeExtensionSetting(tester, extensionIndex: 2, enable: false);
    expect(extensionService.availableExtensions.value.length, 7);
    expect(extensionService.visibleExtensions.value.length, 5);
    await _verifyExtensionTabVisibility(
      tester,
      extensionIndex: 2,
      visible: false,
    );
    await _verifyExtensionsSettingsMenu(
      tester,
      [
        ExtensionEnabledState.disabled,
        ExtensionEnabledState.enabled,
        ExtensionEnabledState.disabled,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
        ExtensionEnabledState.none,
      ],
    );
  });
}

Future<void> _switchToExtensionScreen(
  WidgetTester tester, {
  required int extensionIndex,
  bool initialLoad = false,
}) async {
  final extensionConfig =
      extensionService.availableExtensions.value[extensionIndex];
  await switchToScreen(
    tester,
    tabIcon: extensionConfig.icon,
    screenId: extensionConfig.displayName,
    warnIfTapMissed: false,
  );
  await tester.pump(safePumpDuration);

  if (initialLoad) {
    logStatus(
      'verify the first load state for the ${extensionConfig.name}'
      ' extension screen',
    );
    expect(find.byType(EnableExtensionPrompt), findsOneWidget);
    expect(find.byType(EmbeddedExtensionView), findsNothing);
  }
}

Future<void> _verifyExtensionTabVisibility(
  WidgetTester tester, {
  required int extensionIndex,
  required bool visible,
}) async {
  logStatus(
    'verify the extension at index $extensionIndex is '
    '${!visible ? 'not' : ''} visible',
  );
  final extensionConfig =
      extensionService.availableExtensions.value[extensionIndex];
  final tabFinder = await findTab(tester, extensionConfig.icon);
  expect(tabFinder.evaluate(), visible ? isNotEmpty : isEmpty);
}

Future<void> _answerEnableExtensionPrompt(
  WidgetTester tester, {
  required bool enable,
}) async {
  logStatus('verify we can ${enable ? 'enable' : 'hide'} an extension');
  final buttonFinder = find.descendant(
    of: find.byType(EnableExtensionPrompt),
    matching: find.text(enable ? 'Enable' : 'No, hide this screen'),
  );
  expect(buttonFinder, findsOneWidget);
  await tester.tap(buttonFinder);
  await tester.pump(longPumpDuration);

  expect(find.byType(EnableExtensionPrompt), findsNothing);
  expect(
    find.byType(EmbeddedExtensionView),
    enable ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(HtmlElementView),
    enable ? findsOneWidget : findsNothing,
  );
}

Future<void> _verifyContextMenuActions(WidgetTester tester) async {
  logStatus('verify we can perform context menu actions');
  final contextMenuFinder = find.descendant(
    of: find.byType(EmbeddedExtensionHeader),
    matching: find.byType(ContextMenuButton),
  );
  expect(contextMenuFinder, findsOneWidget);
  await tester.tap(contextMenuFinder);
  await tester.pump(shortPumpDuration);

  final disableExtensionFinder = find.text('Disable extension');
  final forceReloadExtensionFinder = find.text('Force reload extension');
  expect(disableExtensionFinder, findsOneWidget);
  expect(forceReloadExtensionFinder, findsOneWidget);

  logStatus('verify we can force reload the extension');
  await tester.tap(forceReloadExtensionFinder);
  await tester.pumpAndSettle(shortPumpDuration);

  logStatus('verify we can disable the extension from the context menu');
  await tester.tap(contextMenuFinder);
  await tester.pump(shortPumpDuration);
  await tester.tap(disableExtensionFinder);
  await tester.pumpAndSettle(shortPumpDuration);
  await tester.tap(find.text('YES, DISABLE'));
  await tester.pumpAndSettle(safePumpDuration);
}

Future<void> _verifyExtensionsSettingsMenu(
  WidgetTester tester,
  List<ExtensionEnabledState> enabledStates, {
  bool closeMenuWhenDone = true,
}) async {
  await _openExtensionSettingsMenu(tester);

  expect(find.byType(ExtensionSetting), findsNWidgets(enabledStates.length));
  final toggleButtonGroups = tester
      .widgetList(find.byType(DevToolsToggleButtonGroup))
      .cast<DevToolsToggleButtonGroup>()
      .toList();
  for (int i = 0; i < toggleButtonGroups.length; i++) {
    final group = toggleButtonGroups[i];
    final expectedStates = switch (enabledStates[i]) {
      ExtensionEnabledState.enabled => [true, false],
      ExtensionEnabledState.disabled => [false, true],
      _ => [false, false],
    };
    expect(group.selectedStates, expectedStates);
  }
  if (closeMenuWhenDone) {
    await _closeExtensionSettingsMenu(tester);
  }
}

Future<void> _openExtensionSettingsMenu(WidgetTester tester) async {
  await tester.tap(find.byType(ExtensionSettingsAction));
  await tester.pumpAndSettle(shortPumpDuration);
}

Future<void> _closeExtensionSettingsMenu(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ExtensionSettingsDialog),
      matching: find.byType(DialogCloseButton),
    ),
  );
  await tester.pumpAndSettle(safePumpDuration);
}

Future<void> _changeExtensionSetting(
  WidgetTester tester, {
  required int extensionIndex,
  required bool enable,
}) async {
  final settingValue = enable ? 'Enabled' : 'Disabled';
  logStatus(
    'changing the extension setting at index $extensionIndex to value $settingValue',
  );
  await _openExtensionSettingsMenu(tester);
  final extensionSetting = tester
      .widgetList(find.byType(DevToolsToggleButtonGroup))
      .cast<DevToolsToggleButtonGroup>()
      .toList()[extensionIndex];
  await tester.tap(
    find.descendant(
      of: find.byWidget(extensionSetting),
      matching: find.text(enable ? 'Enabled' : 'Disabled'),
    ),
  );
  await tester.pumpAndSettle(shortPumpDuration);
  await _closeExtensionSettingsMenu(tester);
}

Future<void> _verifyExtensionVisibilitySetting(WidgetTester tester) async {
  logStatus('verify we can toggle the show only enabled extensions setting');
  expect(
    preferences.devToolsExtensions.showOnlyEnabledExtensions.value,
    isFalse,
  );
  expect(extensionService.visibleExtensions.value.length, 7);
  // No need to open the settings menu as it should already be open.
  await _toggleShowOnlyEnabledExtensions(tester);
  expect(
    preferences.devToolsExtensions.showOnlyEnabledExtensions.value,
    isTrue,
  );
  expect(extensionService.visibleExtensions.value.length, 0);

  // Return the setting to its original state.
  await _toggleShowOnlyEnabledExtensions(tester);
  expect(
    preferences.devToolsExtensions.showOnlyEnabledExtensions.value,
    isFalse,
  );
  expect(extensionService.visibleExtensions.value.length, 7);

  await _closeExtensionSettingsMenu(tester);
}

Future<void> _toggleShowOnlyEnabledExtensions(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ExtensionSettingsDialog),
      matching: find.byType(NotifierCheckbox),
    ),
  );
  await tester.pumpAndSettle(shortPumpDuration);
}
