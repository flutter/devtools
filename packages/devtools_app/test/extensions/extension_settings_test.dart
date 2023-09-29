// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/extensions/extension_settings.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/matchers/matchers.dart';
import '../test_infra/test_data/extensions.dart';

void main() {
  late ExtensionSettingsDialog dialog;

  group('$ExtensionSettingsDialog', () {
    setUp(() async {
      dialog = const ExtensionSettingsDialog();
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(
        ExtensionService,
        await createMockExtensionServiceWithDefaults(testExtensions),
      );
      setGlobal(IdeTheme, IdeTheme());
    });

    testWidgets(
      'builds dialog with no available extensions',
      (WidgetTester tester) async {
        setGlobal(
          ExtensionService,
          await createMockExtensionServiceWithDefaults([]),
        );
        await tester.pumpWidget(wrapSimple(dialog));
        expect(find.text('DevTools Extensions'), findsOneWidget);
        expect(
          find.textContaining('Extensions are provided by the pub packages'),
          findsOneWidget,
        );
        expect(find.text('No extensions available.'), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        expect(find.byType(ExtensionSetting), findsNothing);
      },
    );

    testWidgets(
      'builds dialog with available extensions',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapSimple(dialog));
        expect(find.text('DevTools Extensions'), findsOneWidget);
        expect(
          find.textContaining('Extensions are provided by the pub packages'),
          findsOneWidget,
        );
        expect(find.text('No extensions available.'), findsNothing);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(ExtensionSetting), findsNWidgets(3));
        await expectLater(
          find.byWidget(dialog),
          matchesDevToolsGolden(
            '../test_infra/goldens/extensions/settings_state_none.png',
          ),
        );
      },
    );

    testWidgets(
      'pressing toggle buttons makes calls to the $ExtensionService',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapSimple(dialog));

        expect(
          extensionService.enabledStateListenable(barExtension.name).value,
          ExtensionEnabledState.none,
        );
        expect(
          extensionService.enabledStateListenable(fooExtension.name).value,
          ExtensionEnabledState.none,
        );
        expect(
          extensionService.enabledStateListenable(providerExtension.name).value,
          ExtensionEnabledState.none,
        );

        final barSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) => setting.extension.name.caseInsensitiveEquals('bar'),
            )
            .first;
        final fooSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) => setting.extension.name.caseInsensitiveEquals('foo'),
            )
            .first;
        final providerSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) =>
                  setting.extension.name.caseInsensitiveEquals('provider'),
            )
            .first;

        // Enable the 'bar' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(barSetting),
            matching: find.text('Enabled'),
          ),
        );
        expect(
          extensionService.enabledStateListenable(barExtension.name).value,
          ExtensionEnabledState.enabled,
        );

        // Enable the 'foo' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(fooSetting),
            matching: find.text('Enabled'),
          ),
        );
        expect(
          extensionService.enabledStateListenable(fooExtension.name).value,
          ExtensionEnabledState.enabled,
        );

        // Disable the 'provider' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(providerSetting),
            matching: find.text('Disabled'),
          ),
        );
        expect(
          extensionService.enabledStateListenable(providerExtension.name).value,
          ExtensionEnabledState.disabled,
        );

        await tester.pumpWidget(wrapSimple(dialog));
        await expectLater(
          find.byWidget(dialog),
          matchesDevToolsGolden(
            '../test_infra/goldens/extensions/settings_state_modified.png',
          ),
        );
      },
    );

    testWidgets(
      'toggle buttons update for changes to value notifiers',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapSimple(dialog));
        await expectLater(
          find.byWidget(dialog),
          matchesDevToolsGolden(
            '../test_infra/goldens/extensions/settings_state_none.png',
          ),
        );

        await extensionService.setExtensionEnabledState(
          barExtension,
          enable: true,
        );
        await extensionService.setExtensionEnabledState(
          fooExtension,
          enable: true,
        );
        await extensionService.setExtensionEnabledState(
          providerExtension,
          enable: false,
        );

        await tester.pumpWidget(wrapSimple(dialog));
        await expectLater(
          find.byWidget(dialog),
          matchesDevToolsGolden(
            '../test_infra/goldens/extensions/settings_state_modified.png',
          ),
        );
      },
    );
  });
}
