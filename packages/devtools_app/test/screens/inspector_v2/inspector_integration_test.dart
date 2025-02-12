// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:devtools_app/devtools_app.dart'
    hide InspectorScreenBodyState, InspectorScreenBody, InspectorRowContent;
import 'package:devtools_app/src/screens/inspector/inspector_screen_body.dart'
    as legacy;
import 'package:devtools_app/src/screens/inspector_shared/inspector_controls.dart';
import 'package:devtools_app/src/screens/inspector_v2/inspector_screen_body.dart';
import 'package:devtools_app/src/screens/inspector_v2/inspector_tree_controller.dart';
import 'package:devtools_app/src/screens/inspector_v2/widget_properties/properties_view.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../../test_infra/flutter_test_environment.dart';
import '../../test_infra/matchers/matchers.dart';

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
    useTempDirectory: true,
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
    // Enable the V2 inspector:
    preferences.inspector.setLegacyInspectorEnabled(false);
  });

  tearDown(() async {
    await env.tearDownEnvironment(force: true);
    // Re-set changes to preferences:
    preferences.inspector.setLegacyInspectorEnabled(true);
  });

  tearDownAll(() {
    env.finalTeardown();
  });

  group('screenshot tests', () {
    testWidgetsWithWindowSize('initial load', windowSize, (
      WidgetTester tester,
    ) async {
      expect(serviceConnection.serviceManager.service, equals(env.service));
      expect(serviceConnection.serviceManager.isolateManager, isNotNull);

      await _loadInspectorUI(tester);

      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_v2_initial_load.png',
        ),
      );
    });

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
            '../../test_infra/goldens/integration_inspector_v2_after_hot_restart.png',
          ),
        );
      },
      skip: true, // https://github.com/flutter/devtools/issues/8179
    );

    testWidgetsWithWindowSize('widget selection', windowSize, (
      WidgetTester tester,
    ) async {
      await _loadInspectorUI(tester);

      // Select the Center widget (row index #16)
      await tester.tap(find.richText('Center'));
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_v2_select_center.png',
        ),
      );

      // Verify the properties are displayed:
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
    });

    testWidgetsWithWindowSize(
      'expand and collapse implementation widgets',
      windowSize,
      (WidgetTester tester) async {
        await _loadInspectorUI(tester);

        // Toggle implementation widgets on.
        await _toggleImplementationWidgets(tester);

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
            '../../test_infra/goldens/integration_inspector_v2_implementation_widgets_expanded.png',
          ),
        );

        // Confirm the HeroControllerScope is visible, and select it:
        expect(hideableNodeFinder, findsOneWidget);
        await tester.tap(hideableNodeFinder);
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../../test_infra/goldens/integration_inspector_v2_hideable_widget_selected.png',
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
            '../../test_infra/goldens/integration_inspector_v2_implementation_widgets_collapsed.png',
          ),
        );
      },
    );

    testWidgetsWithWindowSize('search for implementation widgets', windowSize, (
      WidgetTester tester,
    ) async {
      await _loadInspectorUI(tester);

      // Toggle implementation widgets on.
      await _toggleImplementationWidgets(tester);

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
          '../../test_infra/goldens/integration_inspector_v2_hideable_widget_selected_from_search.png',
        ),
      );
    });
  });

  testWidgetsWithWindowSize('hide all implementation widgets', windowSize, (
    WidgetTester tester,
  ) async {
    await _loadInspectorUI(tester);

    // Toggle implementation widgets on.
    await _toggleImplementationWidgets(tester);

    // Confirm the hidden widgets are visible behind affordances like "X more
    // widgets".
    expect(find.richTextContaining('more widgets...'), findsWidgets);

    // Toggle implementation widgets off.
    await _toggleImplementationWidgets(tester);

    // Confirm that the hidden widgets are no longer visible.
    expect(find.richTextContaining('more widgets...'), findsNothing);
    await expectLater(
      find.byType(InspectorScreenBody),
      matchesDevToolsGolden(
        '../../test_infra/goldens/integration_inspector_v2_implementation_widgets_hidden.png',
      ),
    );

    // Refresh the tree.
    final refreshTreeButton = find.descendant(
      of: find.byType(ToolbarAction),
      matching: find.byIcon(Icons.refresh),
    );

    await tester.tap(refreshTreeButton);
    await tester.pumpAndSettle(inspectorChangeSettleTime);

    // Confirm that the hidden widgets are still not visible.
    expect(find.richTextContaining('more widgets...'), findsNothing);
  });

  // TODO(elliette): Expand into test group for cases when:
  // - selected widget is implementation widget and implementation widgets are hidden (this test case)
  // - selected widget is implementation widget and implementation widgets are visible
  // - selected widget is not implementation widget and implementation widgets are hidden
  // - selected widget is not implementation widget and implementation widgets are visible
  testWidgetsWithWindowSize('selecting implementation widget', windowSize, (
    WidgetTester tester,
  ) async {
    // Load the Inspector.
    await _loadInspectorUI(tester);

    // Toggle implementation widgets on.
    await _toggleImplementationWidgets(tester);

    await tester.pumpAndSettle(inspectorChangeSettleTime);
    final state =
        tester.state(find.byType(InspectorScreenBody))
            as InspectorScreenBodyState;

    // Find the first Text diagnostic node.
    final diagnostics = state.controller.inspectorTree.rowsInTree.value.map(
      (row) => row!.node.diagnostic,
    );
    final textDiagnostic =
        diagnostics.firstWhere((d) => d?.description == 'Text')!;
    expect(textDiagnostic.isCreatedByLocalProject, isTrue);

    // Toggle implementation widgets off.
    await _toggleImplementationWidgets(tester);

    // Verify the Text diagnostic node is still in the tree.
    final diagnosticsNow = state.controller.inspectorTree.rowsInTree.value.map(
      (row) => row!.node.diagnostic,
    );
    expect(
      diagnosticsNow.any((d) => d?.valueRef == textDiagnostic.valueRef),
      isTrue,
    );

    // Get the RichText child of the Text diagnostic node.
    final service = serviceConnection.inspectorService as InspectorService;
    final group = service.createObjectGroup('test-group');
    final textSubtree = await group.getDetailsSubtree(textDiagnostic);
    final richTextDiagnostic = (await textSubtree!.children)!.firstWhere(
      (child) => child.description == 'RichText',
    );

    // Verify the RichText child is an implementation node that is not in the tree.
    expect(richTextDiagnostic.isCreatedByLocalProject, isFalse);
    expect(
      diagnosticsNow.any((d) => d?.valueRef == richTextDiagnostic.valueRef),
      isFalse,
    );

    // Mimic selecting the RichText diagnostic node with the on-device inspector.
    await group.setSelectionInspector(richTextDiagnostic.valueRef, false);
    await tester.pumpAndSettle(inspectorChangeSettleTime);

    // Verify the Text node is now selected.
    final selectedNode = state.controller.selectedNode.value;
    expect(selectedNode!.diagnostic!.valueRef, equals(textDiagnostic.valueRef));

    // Verify the notification about selecting an implementation widget is displayed.
    expect(
      find.text('Selected an implementation widget of Text: RichText.'),
      findsOneWidget,
    );
  });

  testWidgetsWithWindowSize('can revert to legacy inspector', windowSize, (
    WidgetTester tester,
  ) async {
    await _loadInspectorUI(tester);

    // Select the Center widget (row index #16)
    await tester.tap(find.richText('Center'));
    await tester.pumpAndSettle(inspectorChangeSettleTime);

    // Disable Inspector V2:
    await toggleLegacyInspector(tester);
    await tester.pumpAndSettle(inspectorChangeSettleTime);

    // Verify the legacy inspector is visible:
    await expectLater(
      find.byType(legacy.InspectorScreenBody),
      matchesDevToolsGolden(
        '../../test_infra/goldens/integration_inspector_v2_revert_to_legacy.png',
      ),
    );
  });

  // Test to verify https://github.com/flutter/devtools/issues/8487 is fixed.
  testWidgetsWithWindowSize(
    'revert to legacy inspector, hot-restart, and back to new inspector',
    windowSize,
    (WidgetTester tester) async {
      await _loadInspectorUI(tester);

      // Disable Inspector V2.
      await toggleLegacyInspector(tester);
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Verify the legacy inspector is visible.
      expect(find.richTextContaining('Widget Details Tree'), findsOneWidget);

      // Trigger a hot restart.
      await env.flutter!.hotRestart();
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Enable Inspector V2.
      await toggleLegacyInspector(tester);
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Verify the legacy inspector is not visible.
      expect(find.richTextContaining('Widget Details Tree'), findsNothing);

      // Wait for the widget tree to load.
      final centerWidgetFinder = find.richText('Center');
      final centerWidgetFinderWithRetries = await retryUntilFound(
        centerWidgetFinder,
        tester: tester,
        retries: 10,
      );
      expect(centerWidgetFinderWithRetries, findsOneWidget);
    },
    skip: true, // https://github.com/flutter/devtools/issues/8490
  );

  testWidgetsWithWindowSize(
    'tree nodes contain only essential information',
    windowSize,
    (WidgetTester tester) async {
      const requiredDetailsForTreeNode = [
        'description',
        'shouldIndent',
        'valueId',
        'widgetRuntimeType',
      ];
      const possibleDetailsForTreeNode = [
        'textPreview',
        'children',
        'createdByLocalProject',
        // TODO(elliette): Once we update to the Flutter version with
        // https://github.com/flutter/flutter/pull/159701, this should be
        // deleted.
        'truncated',
      ];
      const extraneousDetailsForTreeNode = [
        'creationLocation',
        'type',
        'style',
        'hasChildren',
        'stateful',
      ];

      await _loadInspectorUI(tester);
      final state =
          tester.state(find.byType(InspectorScreenBody))
              as InspectorScreenBodyState;
      final rowsInTree = state.controller.inspectorTree.rowsInTree.value;

      for (final row in rowsInTree) {
        final detailKeys = row?.node.diagnostic?.json.keys ?? const <String>[];
        expect(
          requiredDetailsForTreeNode.every(
            (detail) => detailKeys.contains(detail),
          ),
          isTrue,
        );
        expect(
          detailKeys.every(
            (detail) =>
                requiredDetailsForTreeNode.contains(detail) ||
                possibleDetailsForTreeNode.contains(detail),
          ),
          isTrue,
        );
        expect(
          detailKeys.none(
            (detail) => extraneousDetailsForTreeNode.contains(detail),
          ),
          isTrue,
        );
      }
    },
  );

  group('auto-refresh after code edits', () {
    final flutterAppMainPath = p.join(env.testAppDirectory, 'lib', 'main.dart');
    String flutterMainContents = '';

    setUp(() {
      // Save contents of main.dart file.
      flutterMainContents = File(flutterAppMainPath).readAsStringSync();

      // Enable auto-refresh.
      preferences.inspector.setAutoRefreshEnabled(true);
    });

    tearDown(() {
      // Re-set contents of main.dart.
      File(
        flutterAppMainPath,
      ).writeAsStringSync(flutterMainContents, flush: true);

      // Re-set changes to auto refresh.
      preferences.inspector.setAutoRefreshEnabled(true);
    });

    void makeEditToFlutterMain({
      required String toReplace,
      required String replaceWith,
    }) {
      final file = File(flutterAppMainPath);
      final fileContents = file.readAsStringSync();
      file.writeAsStringSync(
        fileContents.replaceAll(toReplace, replaceWith),
        flush: true,
      );
    }

    testWidgetsWithWindowSize('changing parent widget of selected', windowSize, (
      WidgetTester tester,
    ) async {
      await _loadInspectorUI(tester);

      // Toggle implementation widgets on.
      await _toggleImplementationWidgets(tester);

      // Give time for the initial animation to complete.
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Verify the Text widget is after the Center widget.
      expect(
        _treeRowsAreInOrder(
          treeRowDescriptions: ['Center', 'Text: "Hello, World!"'],
          startingAtIndex: 15,
        ),
        isTrue,
      );

      // Select the Text widget (row index #16).
      await tester.tap(_findTreeRowMatching('Text: "Hello, World!"'));
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Verify the Text widget is selected (its properties are displayed):
      verifyPropertyIsVisible(
        name: 'data',
        value: '"Hello, World!"',
        tester: tester,
      );

      // Make edit to main.dart to replace Center with an Align.
      makeEditToFlutterMain(toReplace: 'Center', replaceWith: 'Align');
      await env.flutter!.hotReload();
      await tester.pumpAndSettle(inspectorChangeSettleTime);

      // Verify the Align is now in the widget tree instead of Center.
      expect(
        _treeRowsAreInOrder(
          treeRowDescriptions: ['Align', 'Text: "Hello, World!"'],
          startingAtIndex: 15,
        ),
        isTrue,
      );

      // Verify the Text widget is still selected (its properties are displayed):
      verifyPropertyIsVisible(
        name: 'data',
        value: '"Hello, World!"',
        tester: tester,
      );
    });
  });

  group('widget errors', () {
    testWidgetsWithWindowSize('show navigator and error labels', windowSize, (
      WidgetTester tester,
    ) async {
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
        wrapWithInspectorControllers(Builder(builder: screen.build)),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await _waitForFlutterFrame(tester);

      await env.flutter!.hotReload();
      // Give time for the initial animation to complete.
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_v2_errors_1_initial_load.png',
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
          '../../test_infra/goldens/integration_inspector_v2_errors_2_error_selected.png',
        ),
      );
    });
  });
}

Future<void> _toggleImplementationWidgets(WidgetTester tester) async {
  // Tap the "Show Implementation Widgets" button (selected by default).
  final showImplementationWidgetsButton = find.descendant(
    of: find.byType(DevToolsToggleButton),
    matching: find.text('Show Implementation Widgets'),
  );
  expect(showImplementationWidgetsButton, findsOneWidget);
  await tester.tap(showImplementationWidgetsButton);
  await tester.pumpAndSettle(inspectorChangeSettleTime);
}

Future<void> _loadInspectorUI(WidgetTester tester) async {
  final screen = InspectorScreen();
  await tester.pumpWidget(
    wrapWithInspectorControllers(Builder(builder: screen.build)),
  );
  await tester.pump(const Duration(seconds: 1));
  await _waitForFlutterFrame(tester);

  await tester.pumpAndSettle(inspectorChangeSettleTime);
}

Future<void> _waitForFlutterFrame(
  WidgetTester tester, {
  bool isInitialLoad = true,
}) async {
  final state =
      tester.state(find.byType(InspectorScreenBody))
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

Future<void> toggleLegacyInspector(WidgetTester tester) async {
  // Open settings dialog.
  final inspectorSettingsDialogButton = find.descendant(
    of: find.byType(InspectorServiceExtensionButtonGroup),
    matching: find.byType(SettingsOutlinedButton),
  );
  await tester.tap(inspectorSettingsDialogButton);
  await tester.pumpAndSettle(inspectorChangeSettleTime);

  // Toggle the "legacy Inspector" checkbox.
  final settingsRow = find.ancestor(
    of: find.richTextContaining('Use legacy inspector'),
    matching: find.byType(Row),
  );
  final inspectorCheckbox = find.descendant(
    of: settingsRow,
    matching: find.byType(NotifierCheckbox),
  );
  await tester.tap(inspectorCheckbox);
  await tester.pumpAndSettle(inspectorChangeSettleTime);

  // Close the settings dialog.
  final closeButton = find.byType(DialogCloseButton);
  await tester.tap(closeButton);
  await tester.pumpAndSettle(inspectorChangeSettleTime);
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
    matching: find.richText(value),
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

bool _treeRowsAreInOrder({
  required List<String> treeRowDescriptions,
  required int startingAtIndex,
}) {
  final treeRowIndices = <int>[];

  for (final description in treeRowDescriptions) {
    final treeRow = _getWidgetFromFinder<InspectorRowContent>(
      _findTreeRowMatching(description),
    );
    treeRowIndices.add(treeRow.row.index);
  }

  int indexToCheck = startingAtIndex;
  for (final index in treeRowIndices) {
    if (index == indexToCheck) {
      indexToCheck++;
    } else {
      return false;
    }
  }
  return true;
}

Finder _findTreeRowMatching(String description) => find.ancestor(
  of: find.richText(description),
  matching: find.byType(InspectorRowContent),
);

T _getWidgetFromFinder<T>(Finder finder) =>
    finder.first.evaluate().first.widget as T;
