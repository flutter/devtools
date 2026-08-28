// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late AccessibilityScreen screen;
  late AccessibilityController controller;
  const windowSize = Size(1000.0, 1000.0);

  group('Accessibility Screen', () {
    Future<void> pumpAccessibilityScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const AccessibilityScreenBody(),
          accessibility: controller,
        ),
      );
    }

    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager();
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isFlutterWebAppNow,
      ).thenReturn(false);
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow,
      ).thenReturn(false);
      when(
        fakeServiceConnection.errorBadgeManager.errorCountNotifier(
          'accessibility',
        ),
      ).thenReturn(ValueNotifier<int>(0));

      setGlobal(NotificationService, NotificationService());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());

      controller = AccessibilityController();
      screen = AccessibilityScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Accessibility'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds split view with panes', windowSize, (
      WidgetTester tester,
    ) async {
      await pumpAccessibilityScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AccessibilityScreenBody), findsOneWidget);
      expect(find.byType(SplitPane), findsAtLeastNWidgets(1));

      // Overrides pane should be visible
      expect(find.byType(AccessibilityOverridesPane), findsOneWidget);

      // Semantics Tree pane should be visible
      expect(find.byType(AccessibilitySemanticsTreePane), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'renders all override controls in AccessibilityOverridesPane',
      windowSize,
      (WidgetTester tester) async {
        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(find.text('Accessibility Overrides'), findsOneWidget);
        expect(
          find.text(
            'Simulate and test accessibility settings on the connected device in real-time.',
          ),
          findsOneWidget,
        );

        // Brightness controls
        expect(find.text('Brightness'), findsOneWidget);
        expect(
          find.text('Override the color scheme mode of the app.'),
          findsOneWidget,
        );
        expect(
          find.byType(RoundedDropDownButton<BrightnessOverride>),
          findsOneWidget,
        );

        // Text Scale controls
        expect(find.text('Text Scale'), findsOneWidget);
        expect(find.text('Scale the system font size.'), findsOneWidget);
        expect(find.text('1.00x'), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);

        // Switches
        expect(find.text('Bold Text'), findsOneWidget);
        expect(
          find.text('Forces all text in the application to be bold.'),
          findsOneWidget,
        );
        expect(find.text('Screen Reader Debugger'), findsOneWidget);
        expect(
          find.text('Debug and test screen reader layouts.'),
          findsOneWidget,
        );
        expect(find.text('High Contrast'), findsOneWidget);
        expect(
          find.text('Increases the contrast of text and icons.'),
          findsOneWidget,
        );
        expect(find.byType(Switch), findsNWidgets(3));
      },
    );

    testWidgetsWithWindowSize(
      'interacting with override controls updates controller state',
      windowSize,
      (WidgetTester tester) async {
        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        Finder findSwitchFor(String label) {
          return find.descendant(
            of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
            matching: find.byType(Switch),
          );
        }

        // 1. Test Brightness Dropdown
        expect(controller.brightness.value, BrightnessOverride.system);
        await tester.tap(
          find.byType(RoundedDropDownButton<BrightnessOverride>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Light Mode').last);
        await tester.pumpAndSettle();
        expect(controller.brightness.value, BrightnessOverride.light);

        // 2. Test Bold Text Switch
        expect(controller.boldText.value, isFalse);
        final boldTextSwitch = findSwitchFor('Bold Text');
        await tester.ensureVisible(boldTextSwitch);
        await tester.pumpAndSettle();
        await tester.tap(boldTextSwitch);
        await tester.pumpAndSettle();
        expect(controller.boldText.value, isTrue);

        // 3. Test Screen Reader Debugger Switch
        expect(controller.screenReader.value, isFalse);
        final screenReaderSwitch = findSwitchFor('Screen Reader Debugger');
        await tester.ensureVisible(screenReaderSwitch);
        await tester.pumpAndSettle();
        await tester.tap(screenReaderSwitch);
        await tester.pumpAndSettle();
        expect(controller.screenReader.value, isTrue);

        // 4. Test High Contrast Switch
        expect(controller.highContrast.value, isFalse);
        final highContrastSwitch = findSwitchFor('High Contrast');
        await tester.ensureVisible(highContrastSwitch);
        await tester.pumpAndSettle();
        await tester.tap(highContrastSwitch);
        await tester.pumpAndSettle();
        expect(controller.highContrast.value, isTrue);
      },
    );

    testWidgetsWithWindowSize(
      'renders semantics tree when nodes are loaded',
      windowSize,
      (WidgetTester tester) async {
        final rootNode = SemanticsNodeModel(
          id: '0',
          label: 'Root Node',
          flags: ['isHeader'],
          widgetName: 'HeaderWidget',
          rectString: 'rect: Rect.fromLTWH(0, 0, 100, 50)',
        );
        controller.semanticsRoots.value = [rootNode];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(find.text('SemanticsNode #0'), findsAtLeastNWidgets(1));
        expect(find.text('"Root Node"'), findsAtLeastNWidgets(1));
        expect(find.text('HeaderWidget'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'renders semantics tree error state when error occurs',
      windowSize,
      (WidgetTester tester) async {
        controller.semanticsTreeError.value =
            'Failed to load semantics tree: network error.';

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(
          find.text('Failed to load semantics tree: network error.'),
          findsOneWidget,
        );
        expect(find.text('Try Again'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'renders parent and child nodes in semantics tree',
      windowSize,
      (WidgetTester tester) async {
        final childNode = SemanticsNodeModel(
          id: '1',
          label: 'Child Node',
          flags: ['isButton'],
          widgetName: 'ElevatedButton',
        );
        final rootNode = SemanticsNodeModel(
          id: '0',
          label: 'Root Node',
          widgetName: 'Column',
        )..addChild(childNode);

        rootNode.expandCascading();
        controller.semanticsRoots.value = [rootNode];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(find.text('SemanticsNode #0'), findsOneWidget);
        expect(find.text('SemanticsNode #1'), findsOneWidget);
        expect(find.text('"Child Node"'), findsOneWidget);
        expect(find.text('ElevatedButton'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'renders empty state with Load Semantics Tree button when no roots',
      windowSize,
      (WidgetTester tester) async {
        controller.semanticsRoots.value = [];
        await pumpAccessibilityScreen(tester);
        controller.semanticsTreeError.value = null;
        await tester.pumpAndSettle();

        expect(
          find.text(
            'No semantics tree loaded. Inspect the accessibility hierarchy of the connected app.',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(DevToolsButton, 'Load Semantics Tree'),
          findsOneWidget,
        );
        expect(find.byType(RefreshButton), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'renders refresh button when roots are loaded',
      windowSize,
      (WidgetTester tester) async {
        final rootNode = SemanticsNodeModel(id: '0', label: 'Root Node');
        controller.semanticsRoots.value = [rootNode];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(find.byType(RefreshButton), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'renders appropriate icon for node with hasCheckedState flag',
      windowSize,
      (WidgetTester tester) async {
        final node = SemanticsNodeModel(
          id: '0',
          label: 'Checkbox Node',
          flags: ['hasCheckedState'],
        );
        controller.semanticsRoots.value = [node];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
      },
    );
  });
}
