// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'dart:ui' show SemanticsFlag;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/utils/view_metrics_override_utils.dart';

void main() {
  late AccessibilityScreen screen;
  late AccessibilityController controller;
  late FakeViewMetricsOverrideExtension fakeExtension;
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
      final fakeServiceConnection = ViewMetricsOverrideServiceConnection();
      fakeExtension = fakeServiceConnection.extension;
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

      // Semantics Tree pane should be visible
      expect(find.byType(AccessibilitySemanticsTreePane), findsOneWidget);

      // Semantics Node Details pane should be visible
      expect(find.byType(SemanticsNodeDetailsPane), findsOneWidget);

      // Overrides pane should be visible
      expect(find.byType(AccessibilityOverridesPane), findsOneWidget);
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
        expect(find.text('System default'), findsOneWidget);
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

    Finder findSwitchFor(String label) {
      return find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
        matching: find.byType(Switch),
      );
    }

    testWidgetsWithWindowSize(
      'interacting with override controls updates the app and the controller',
      windowSize,
      (WidgetTester tester) async {
        await pumpAccessibilityScreen(tester);
        await fakeExtension.register();
        await tester.pumpAndSettle();

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

        // Brightness does not go through ext.flutter.viewMetricsOverride.
        expect(fakeExtension.registry, {
          '0': {
            'boldText': true,
            'accessibleNavigation': true,
            'highContrast': true,
          },
        });

        // Turning a switch off lets the app use the setting of the platform.
        await tester.tap(boldTextSwitch);
        await tester.pumpAndSettle();
        expect(controller.boldText.value, isFalse);
        expect(fakeExtension.registry['0'], {
          'accessibleNavigation': true,
          'highContrast': true,
        });
      },
    );

    testWidgetsWithWindowSize(
      'disables the overrides and explains why while the app does not support them',
      windowSize,
      (WidgetTester tester) async {
        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        final unavailableTooltip = find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip &&
              (widget.message ?? '').contains('profile build'),
        );
        for (final element in find.byType(Switch).evaluate()) {
          expect((element.widget as Switch).onChanged, isNull);
        }
        expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
        expect(unavailableTooltip, findsOneWidget);

        // The controls are enabled once the app registers the extension.
        await fakeExtension.register();
        await tester.pumpAndSettle();
        expect(
          tester.widget<Switch>(findSwitchFor('Bold Text')).onChanged,
          isNotNull,
        );
        expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
        expect(unavailableTooltip, findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'text scale shows the override of the app, and the slider and reset change it',
      windowSize,
      (WidgetTester tester) async {
        fakeExtension.registry['0'] = {
          'textScaling': [
            [1.0, 4.0],
          ],
        };
        await pumpAccessibilityScreen(tester);
        await fakeExtension.register();
        await tester.pumpAndSettle();

        // The slider stays within its range.
        expect(find.text('4.00x'), findsOneWidget);
        expect(tester.widget<Slider>(find.byType(Slider)).value, 3.0);

        await tester.drag(find.byType(Slider), const Offset(-1000, 0));
        await tester.pumpAndSettle();
        expect(find.text('0.50x'), findsOneWidget);
        expect(fakeExtension.registry['0'], {
          'textScaling': [
            [1, 0.5],
          ],
        });

        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();
        expect(find.text('System default'), findsOneWidget);
        expect(fakeExtension.registry, isEmpty);
      },
    );

    testWidgetsWithWindowSize(
      'renders semantics tree when nodes are loaded',
      windowSize,
      (WidgetTester tester) async {
        final rootNode = SemanticsNodeModel(
          id: '0',
          label: 'Root Node',
          flags: {SemanticsFlag.isHeader},
          widgetName: 'HeaderWidget',
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
          flags: {SemanticsFlag.isButton},
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

        expect(
          find.descendant(
            of: find.byType(AccessibilitySemanticsTreePane),
            matching: find.text('SemanticsNode #0'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AccessibilitySemanticsTreePane),
            matching: find.text('SemanticsNode #1'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AccessibilitySemanticsTreePane),
            matching: find.text('"Child Node"'),
          ),
          findsOneWidget,
        );
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
          flags: {SemanticsFlag.hasCheckedState},
        );
        controller.semanticsRoots.value = [node];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'renders node details placeholder when no node is selected',
      windowSize,
      (WidgetTester tester) async {
        controller.semanticsRoots.value = [];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        expect(find.text('Semantics Node Details'), findsOneWidget);
        expect(
          find.text('Select a node in the semantics tree to view its details.'),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'renders root node details automatically and updates when a child node is selected',
      windowSize,
      (WidgetTester tester) async {
        final childNode = SemanticsNodeModel(
          id: '26',
          label: 'CloseButton',
          rect: const Rect.fromLTWH(0, 0, 763, 32),
          flags: {
            SemanticsFlag.isButton,
            SemanticsFlag.hasEnabledState,
            SemanticsFlag.isEnabled,
            SemanticsFlag.isFocusable,
          },
          widgetName: 'CloseButton',
        );
        final rootNode = SemanticsNodeModel(
          id: '0',
          label: 'Root Node',
          value: 'Initial Value',
          hint: 'Tap to interact',
          rect: const Rect.fromLTWH(0, 0, 1000, 1000),
          flags: {SemanticsFlag.isHeader},
        )..addChild(childNode);

        rootNode.expandCascading();
        controller.semanticsRoots.value = [rootNode];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        final detailsPane = find.byType(SemanticsNodeDetailsPane);

        // Initially, root node (#0) is automatically selected
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('SemanticsNode #0'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: detailsPane, matching: find.text('"Root Node"')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('"Initial Value"'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('"Tap to interact"'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('rect: Rect.fromLTWH(0, 0, 1000, 1000)'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: detailsPane, matching: find.text('isHeader')),
          findsOneWidget,
        );

        // Tap child node (#26) in the tree pane
        await tester.tap(
          find.descendant(
            of: find.byType(AccessibilitySemanticsTreePane),
            matching: find.text('SemanticsNode #26'),
          ),
        );
        await tester.pumpAndSettle();

        // Details pane should now display SemanticsNode #26 details
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('SemanticsNode #26'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('"CloseButton"'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('rect: Rect.fromLTWH(0, 0, 763, 32)'),
          ),
          findsOneWidget,
        );
        // Empty value and hint should render as (empty)
        expect(
          find.descendant(of: detailsPane, matching: find.text('(empty)')),
          findsNWidgets(2),
        );
        // Flags chips
        expect(
          find.descendant(of: detailsPane, matching: find.text('isButton')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('hasEnabledState'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: detailsPane, matching: find.text('isEnabled')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: detailsPane, matching: find.text('isFocusable')),
          findsOneWidget,
        );

        // Tap parent node (#0) in the tree pane to select it; its child (#26)
        // should remain expanded and visible in the tree.
        await tester.tap(
          find.descendant(
            of: find.byType(AccessibilitySemanticsTreePane),
            matching: find.text('SemanticsNode #0'),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.selectedSemanticsNode.value, equals(rootNode));
        expect(rootNode.isExpanded, isTrue);
        expect(
          find.descendant(
            of: find.byType(AccessibilitySemanticsTreePane),
            matching: find.text('SemanticsNode #26'),
          ),
          findsOneWidget,
        );

        // Select child (#26) again, then tap the expand/collapse arrow on
        // parent (#0); it should collapse without changing the selected node.
        controller.selectSemanticsNode(childNode);
        await tester.pumpAndSettle();
        expect(controller.selectedSemanticsNode.value, equals(childNode));

        await tester.tap(
          find.descendant(
            of: find.byType(AccessibilitySemanticsTreePane),
            matching: find.byIcon(Icons.keyboard_arrow_down),
          ),
        );
        await tester.pumpAndSettle();

        expect(rootNode.isExpanded, isFalse);
        expect(controller.selectedSemanticsNode.value, equals(childNode));
      },
    );

    testWidgetsWithWindowSize(
      'renders accessibility issues in tree pane and node details pane',
      windowSize,
      (WidgetTester tester) async {
        final nodeWithIssue = SemanticsNodeModel(
          id: '13',
          issues: const [
            AccessibilityIssue(
              rule: 'labeledTapTarget',
              description:
                  'Interactive element has no label for screen readers.',
            ),
          ],
        );
        final rootNode = SemanticsNodeModel(id: '0', label: 'Root Node')
          ..addChild(nodeWithIssue);

        rootNode.expandCascading();
        controller.semanticsRoots.value = [rootNode];

        await pumpAccessibilityScreen(tester);
        await tester.pumpAndSettle();

        final treePane = find.byType(AccessibilitySemanticsTreePane);
        final detailsPane = find.byType(SemanticsNodeDetailsPane);

        // Tree pane should display a warning icon for node #13.
        expect(
          find.descendant(
            of: treePane,
            matching: find.byIcon(Icons.warning_amber_rounded),
          ),
          findsOneWidget,
        );

        // Initially root node (#0) has no issues, so details pane has no issues section.
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.textContaining('Accessibility Issues'),
          ),
          findsNothing,
        );

        // Select node #13 in the tree pane.
        await tester.tap(
          find.descendant(
            of: treePane,
            matching: find.text('SemanticsNode #13'),
          ),
        );
        await tester.pumpAndSettle();

        // Details pane should now show the Accessibility Issues section and card.
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('Accessibility Issues (1)'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text('labeledTapTarget'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: detailsPane,
            matching: find.text(
              'Interactive element has no label for screen readers.',
            ),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
