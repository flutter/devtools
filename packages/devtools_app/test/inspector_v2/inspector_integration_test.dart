// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart'
    hide InspectorScreen, InspectorScreenBodyState, InspectorScreenBody;
import 'package:devtools_app/src/screens/inspector_v2/inspector_screen.dart';
import 'package:devtools_app/src/screens/inspector_v2/widget_properties/properties_view.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../test_infra/flutter_test_environment.dart';
import '../test_infra/matchers/matchers.dart';

// Note: This test uses packages/devtools_app/test/test_infra/fixtures/flutter_app
// running on the flutter-tester device.

// This is a bit conservative to ensure we do not get flakes due to
// slow interactions with the VM Service. This delay could likely be
// reduced to under 1 second without introducing flakes.
const inspectorChangeSettleTime = Duration(seconds: 2);

void main() {
  // We need to use real async in this test so we need to use this binding.
  initializeLiveTestWidgetsFlutterBindingWithAssets();
  const windowSize = Size(2600.0, 1200.0);

  final env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  env.afterEverySetup = () async {
    final service = serviceConnection.inspectorService;
    if (env.reuseTestEnvironment) {
      // Ensure the previous test did not set the selection on the device.
      // TODO(jacobr): add a proper method to WidgetInspectorService that does
      // this. setSelection currently ignores null selection requests which is
      // a misfeature.
      await service!.inspectorLibrary.eval(
        'WidgetInspectorService.instance.selection.clear()',
        isAlive: null,
      );
    }
  };

  setUp(() async {
    await env.setupEnvironment();
  });

  tearDown(() async {
    await env.tearDownEnvironment(force: true);
  });

  group('screenshot tests', () {
    testWidgetsWithWindowSize(
      'initial load',
      windowSize,
      (WidgetTester tester) async {
        expect(serviceConnection.serviceManager.service, equals(env.service));
        expect(serviceConnection.serviceManager.isolateManager, isNotNull);

        await _loadInspectorUI(tester);

        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_initial_load.png',
          ),
        );
      },
    );

    testWidgetsWithWindowSize(
      'loads after a hot-restart',
      windowSize,
      (WidgetTester tester) async {
        // Load the inspector panel.
        await _loadInspectorUI(tester);

        // Expect the Center widget to be visible in the widget tree.
        final centerWidgetFinder = find.richText('Center');
        expect(centerWidgetFinder, findsOneWidget);

        // Trigger a hot-restart and wait for the first Flutter frame.
        await env.flutter!.hotRestart();
        await _waitForFlutterFrame(tester, isInitialLoad: false);

        // Wait for the Center widget to be visible again.
        final centerWidgetFinderWithRetries = await retryUntilFound(
          centerWidgetFinder,
          tester: tester,
        );
        expect(centerWidgetFinderWithRetries, findsOneWidget);

        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_after_hot_restart.png',
          ),
        );
      },
      skip: true, // https://github.com/flutter/devtools/issues/8179
    );

    testWidgetsWithWindowSize(
      'widget selection',
      windowSize,
      (WidgetTester tester) async {
        await _loadInspectorUI(tester);

        // Select the Center widget (row index #16)
        await tester.tap(find.richText('Center'));
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_select_center.png',
          ),
        );

        // Verify the properties are displayed:
        verifyPropertyIsVisible(
          name: 'widget',
          value: 'Center',
          tester: tester,
        );
        verifyPropertyIsVisible(
          name: 'alignment',
          value: 'Alignment.center',
          tester: tester,
        );
        verifyPropertyIsVisible(
          name: 'dependencies',
          value: '[Directionality]',
          tester: tester,
        );
      },
    );

    testWidgetsWithWindowSize(
      'expand and collapse implementation widgets',
      windowSize,
      (WidgetTester tester) async {
        await _loadInspectorUI(tester);

        // Before hidden widgets are expanded, confirm the HeroControllerScope
        // is hidden:
        final hideableNodeFinder = findNodeMatching('HeroControllerScope');
        expect(hideableNodeFinder, findsNothing);

        // Expand the hidden group that contains the HeroControllerScope:
        final expandButton = findExpandCollapseButtonForNode(
          nodeDescription: '71 more widgets...',
          isExpand: true,
        );
        await tester.tap(expandButton);
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_implementation_widgets_expanded.png',
          ),
        );

        // Confirm the HeroControllerScope is visible, and select it:
        expect(hideableNodeFinder, findsOneWidget);
        await tester.tap(hideableNodeFinder);
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_hideable_widget_selected.png',
          ),
        );

        // Collapse the hidden group that contains the HeroControllerScope:
        final collapseButton = findExpandCollapseButtonForNode(
          nodeDescription: 'ScrollConfiguration',
          isExpand: false,
        );
        await tester.tap(collapseButton);
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_implementation_widgets_collapsed.png',
          ),
        );
      },
    );

    testWidgetsWithWindowSize(
      'search for implementation widgets',
      windowSize,
      (WidgetTester tester) async {
        await _loadInspectorUI(tester);

        // Before searching, confirm the HeroControllerScope is hidden:
        final hideableNodeFinder = findNodeMatching('HeroControllerScope');
        expect(hideableNodeFinder, findsNothing);

        // Search for the HeroControllerScope:
        final searchButtonFinder = find.ancestor(
          of: find.byIcon(Icons.search),
          matching: find.byType(ToolbarAction),
        );
        await tester.tap(searchButtonFinder);
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await tester.enterText(find.byType(TextField), 'HeroControllerScope');
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle(inspectorChangeSettleTime);

        // Confirm the HeroControllerScope is visible and selected:
        expect(hideableNodeFinder, findsOneWidget);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_hideable_widget_selected_from_search.png',
          ),
        );
      },
    );
  });

  testWidgetsWithWindowSize(
    'hide all implementation widgets',
    windowSize,
    (WidgetTester tester) async {
      await _loadInspectorUI(tester);

      // Give time for the initial animation to complete.
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Confirm the hidden widgets are visible behind affordances like "X more
      // widgets".
      expect(
        find.richTextContaining('more widgets...'),
        findsWidgets,
      );

      // Tap the "Show Implementation Widgets" button (selected by default).
      final showImplementationWidgetsButton = find.descendant(
        of: find.byType(DevToolsToggleButton),
        matching: find.text('Show Implementation Widgets'),
      );
      expect(showImplementationWidgetsButton, findsOneWidget);
      await tester.tap(showImplementationWidgetsButton);
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Confirm that the hidden widgets are no longer visible.
      expect(find.richTextContaining('more widgets...'), findsNothing);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../test_infra/goldens/integration_inspector_v2_implementation_widgets_hidden.png',
        ),
      );
    },
  );

  group('widget errors', () {
    testWidgetsWithWindowSize(
      'show navigator and error labels',
      windowSize,
      (WidgetTester tester) async {
        await env.setupEnvironment(
          config: const FlutterRunConfiguration(
            withDebugger: true,
            entryScript: 'lib/overflow_errors.dart',
          ),
        );
        expect(serviceConnection.serviceManager.service, equals(env.service));
        expect(serviceConnection.serviceManager.isolateManager, isNotNull);

        final screen = InspectorScreen();
        await tester.pumpWidget(
          wrapWithInspectorControllers(
            Builder(builder: screen.build),
            v2: true,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await _waitForFlutterFrame(tester);

        await env.flutter!.hotReload();
        // Give time for the initial animation to complete.
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_errors_1_initial_load.png',
          ),
        );

        // Navigate so one of the errors is selected.
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
          await tester.pumpAndSettle(inspectorChangeSettleTime);
        }
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_errors_2_error_selected.png',
          ),
        );
      },
    );
  });
}

Future<void> _loadInspectorUI(WidgetTester tester) async {
  final screen = InspectorScreen();
  await tester.pumpWidget(
    wrapWithInspectorControllers(
      Builder(builder: screen.build),
      v2: true,
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await _waitForFlutterFrame(tester);

  await tester.pumpAndSettle(inspectorChangeSettleTime);
}

Future<void> _waitForFlutterFrame(
  WidgetTester tester, {
  bool isInitialLoad = true,
}) async {
  final state = tester.state(find.byType(InspectorScreenBody))
      as InspectorScreenBodyState;
  final controller = state.controller;
  while (!controller.flutterAppFrameReady) {
    // On the initial load, we might have instantiated the controller after the
    // first Flutter frame was sent. In which case, calling `maybeLoadUI` is
    // necessary to ensure we detect that the widget tree is ready.
    if (isInitialLoad) {
      await controller.maybeLoadUI();
    }
    await tester.pump(safePumpDuration);
  }
}

Finder findNodeMatching(String text) => find.ancestor(
      of: find.richTextContaining(text),
      matching: find.byType(DescriptionDisplay),
    );

Finder findExpandCollapseButtonForNode({
  required String nodeDescription,
  required bool isExpand,
}) {
  final hiddenNodeFinder = findNodeMatching(nodeDescription);
  expect(hiddenNodeFinder, findsOneWidget);

  final expandCollapseButtonFinder = find.descendant(
    of: hiddenNodeFinder,
    matching: find.byType(TextButton),
  );
  expect(expandCollapseButtonFinder, findsOneWidget);

  final expandCollapseButtonTextFinder = find.descendant(
    of: expandCollapseButtonFinder,
    matching: find.text(isExpand ? '(expand)' : '(collapse)'),
  );
  expect(expandCollapseButtonTextFinder, findsOneWidget);

  return expandCollapseButtonFinder;
}

void verifyPropertyIsVisible({
  required String name,
  required String value,
  required WidgetTester tester,
}) {
  // Verify the property name is visible:
  final propertyNameFinder = find.descendant(
    of: find.byType(PropertyName),
    matching: find.text(name),
  );
  expect(propertyNameFinder, findsOneWidget);

  // Verify the property value is visible:
  final propertyValueFinder = find.descendant(
    of: find.byType(PropertyValue),
    matching: find.text(value),
  );
  expect(propertyValueFinder, findsOneWidget);

  // Verify the property name and value are aligned:
  final propertyNameCenter = tester.getCenter(propertyNameFinder);
  final propertyValueCenter = tester.getCenter(propertyValueFinder);
  expect(propertyNameCenter.dy, equals(propertyValueCenter.dy));
}

bool areHorizontallyAligned(
  Finder widgetAFinder,
  Finder widgetBFinder, {
  required WidgetTester tester,
}) {
  final widgetACenter = tester.getCenter(widgetAFinder);
  final widgetBCenter = tester.getCenter(widgetBFinder);

  return widgetACenter.dy == widgetBCenter.dy;
}
