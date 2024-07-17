// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart'
    hide InspectorScreen, InspectorScreenBodyState, InspectorScreenBody;
import 'package:devtools_app/src/screens/inspector_v2/inspector_screen.dart';
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

  tearDownAll(() async {
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

        // Give time for the initial animation to complete.
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_initial_load.png',
          ),
        );

        await env.tearDownEnvironment();
      },
    );

    testWidgetsWithWindowSize(
      'widget selection',
      windowSize,
      (WidgetTester tester) async {
        await _loadInspectorUI(tester);

        // Give time for the initial animation to complete.
        await tester.pumpAndSettle(inspectorChangeSettleTime);

        // Select the Center widget (row index #16)
        await tester.tap(find.richText('Center'));
        await tester.pumpAndSettle(inspectorChangeSettleTime);
        await expectLater(
          find.byType(InspectorScreenBody),
          matchesDevToolsGolden(
            '../test_infra/goldens/integration_inspector_v2_select_center.png',
          ),
        );

        await env.tearDownEnvironment();
      },
    );

    testWidgetsWithWindowSize(
      'expand and collapse implementation widgets',
      windowSize,
      (WidgetTester tester) async {
        await _loadInspectorUI(tester);

        // Give time for the initial animation to complete.
        await tester.pumpAndSettle(inspectorChangeSettleTime);

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

        await env.tearDownEnvironment();
      },
    );

    testWidgetsWithWindowSize(
      'search for implementation widgets',
      windowSize,
      (WidgetTester tester) async {
        await _loadInspectorUI(tester);

        // Give time for the initial animation to complete.
        await tester.pumpAndSettle(inspectorChangeSettleTime);

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

        await env.tearDownEnvironment();
      },
    );
  });

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
        final InspectorScreenBodyState state =
            tester.state(find.byType(InspectorScreenBody));
        final controller = state.controller;
        while (!controller.flutterAppFrameReady) {
          await controller.maybeLoadUI();
          await tester.pumpAndSettle();
        }
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

        await env.tearDownEnvironment();
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
  final InspectorScreenBodyState state =
      tester.state(find.byType(InspectorScreenBody));
  final controller = state.controller;
  while (!controller.flutterAppFrameReady) {
    await controller.maybeLoadUI();
    await tester.pumpAndSettle();
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
