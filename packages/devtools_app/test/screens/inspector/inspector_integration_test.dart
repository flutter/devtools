// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../../test_infra/flutter_test_environment.dart';
import '../../test_infra/matchers/matchers.dart';

// This is a bit conservative to ensure we do not get flakes due to
// slow interactions with the VM Service. This delay could likely be
// reduced to under 1 second without introducing flakes.
const inspectorChangeSettleTime = Duration(seconds: 2);

void main() {
  const windowSize = Size(2600.0, 1200.0);
  // We need to use real async in this test so we need to use this binding.
  initializeLiveTestWidgetsFlutterBindingWithAssets();

  late FlutterTestEnvironment env;

  Future<void> resetInspectorSelection() async {
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
  }

  group('screenshot tests', () {
    setUpAll(() {
      env = FlutterTestEnvironment(
        const FlutterRunConfiguration(withDebugger: true),
      );
      env.afterEverySetup = resetInspectorSelection;
    });

    setUp(() async {
      await env.setupEnvironment();
      // Ensure the legacy inspector is enabled:
      preferences.inspector.setLegacyInspectorEnabled(true);
    });

    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    testWidgetsWithWindowSize('navigation', windowSize, (
      WidgetTester tester,
    ) async {
      await env.setupEnvironment();
      expect(serviceConnection.serviceManager.service, equals(env.service));
      expect(serviceConnection.serviceManager.isolateManager, isNotNull);

      final screen = InspectorScreen();
      await tester.pumpWidget(
        wrapWithInspectorControllers(Builder(builder: screen.build)),
      );
      await tester.pump(const Duration(seconds: 1));
      final InspectorScreenBodyState state = tester.state(
        find.byType(InspectorScreenBody),
      );
      final controller = state.controller;
      while (!controller.flutterAppFrameReady) {
        await controller.maybeLoadUI();
        await tester.pumpAndSettle();
      }
      // Give time for the initial animation to complete.
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_initial_load.png',
        ),
      );

      // Click on the Center widget (row index #5)
      await tester.tap(find.richText('Center'));
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_select_center.png',
        ),
      );

      // Select the details tree.
      await tester.tap(
        find.text(InspectorDetailsViewType.widgetDetailsTree.key),
      );
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_select_center_details_tree.png',
        ),
        // Implementation widgets from Flutter framework are not guaranteed to
        // be stable.
        skip: 'https://github.com/flutter/flutter/issues/172037',
      );

      // Select the RichText row.
      await tester.tap(find.richText('RichText'));
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_richtext_selected.png',
        ),
        // Implementation widgets from Flutter framework are not guaranteed to
        // be stable.
        skip: 'https://github.com/flutter/flutter/issues/172037',
      );

      // Test hovering over the icon shown when a property has its default
      // value.
      // TODO(jacobr): support tooltips in the Flutter version of the inspector.
      // https://github.com/flutter/devtools/issues/2570.
      // For example, verify that the tooltip hovering over the default value
      // icons is "Default value".
      // Test selecting a widget.

      // Two 'Scaffold's: a breadcrumb and an actual tree item
      expect(find.richText('Scaffold'), findsNWidgets(2));
      // select Scaffold widget in summary tree.
      await tester.tap(find.richText('Scaffold').last);
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      // This tree is huge. If there is a change to package:flutter it may
      // change. If this happens don't panic and rebaseline the golden.
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_inspector_scaffold_selected.png',
        ),
        // Implementation widgets from Flutter framework are not guaranteed to
        // be stable.
        skip: 'https://github.com/flutter/flutter/issues/172037',
      );

      // The important thing about this is that the details tree should scroll
      // instead of re-rooting as the selected row is already visible in the
      // details tree.
      await tester.tap(find.richText('AnimatedPhysicalModel'));
      await tester.pumpAndSettle(inspectorChangeSettleTime);
      await expectLater(
        find.byType(InspectorScreenBody),
        matchesDevToolsGolden(
          '../../test_infra/goldens/integration_animated_physical_model_selected.png',
        ),
        // Implementation widgets from Flutter framework are not guaranteed to
        // be stable.
        skip: 'https://github.com/flutter/flutter/issues/172037',
      );

      await env.tearDownEnvironment();
    });

    // TODO(jacobr): convert these tests to screenshot tests like the initial
    // state test.
    /*


      // Intentionally trigger multiple quick navigate action to ensure that
      // multiple quick navigation commands in a row do not trigger race
      // conditions getting out of order updates from the server.
      tree.navigateDown();
      tree.navigateDown();
      tree.navigateDown();
      await detailsTree.nextUiFrame;
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center\n'
          '      │     [/icons/inspector/textArea.png]Text\n'
          '      └─▼[A]AppBar <-- selected\n'
          '          [/icons/inspector/textArea.png]Text\n',
        ),
      );
      // Make sure we don't go off the bottom of the tree.
      tree.navigateDown();
      tree.navigateDown();
      tree.navigateDown();
      tree.navigateDown();
      tree.navigateDown();
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center\n'
          '      │     [/icons/inspector/textArea.png]Text\n'
          '      └─▼[A]AppBar\n'
          '          [/icons/inspector/textArea.png]Text <-- selected\n',
        ),
      );
      tree.navigateUp();
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center\n'
          '      │     [/icons/inspector/textArea.png]Text\n'
          '      └─▼[A]AppBar <-- selected\n'
          '          [/icons/inspector/textArea.png]Text\n',
        ),
      );
      tree.navigateLeft();
      await detailsTree.nextUiFrame;
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center\n'
          '      │     [/icons/inspector/textArea.png]Text\n'
          '      └─▶[A]AppBar <-- selected\n',
        ),
      );
      tree.navigateLeft();
      // First navigate left goes to the parent.
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold <-- selected\n'
          '      ├───▼[C]Center\n'
          '      │     [/icons/inspector/textArea.png]Text\n'
          '      └─▶[A]AppBar\n',
        ),
      );
      tree.navigateLeft();
      // Next navigate left closes the parent.
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▶[S]Scaffold <-- selected\n',
        ),
      );

      tree.navigateRight();
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold <-- selected\n'
          '      ├───▼[C]Center\n'
          '      │     [/icons/inspector/textArea.png]Text\n'
          '      └─▶[A]AppBar\n',
        ),
      );

      // Node is already expanded so this is equivalent to navigate down.
      tree.navigateRight();
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center <-- selected\n'
          '      │     [/icons/inspector/textArea.png]Text\n'
          '      └─▶[A]AppBar\n',
        ),
      );

      await detailsTree.nextUiFrame;

      // Make sure the details and main trees have not gotten out of sync.
      expect(
        detailsTree.toStringDeep(hidePropertyLines: true),
        equalsIgnoringHashCodes('▼[C]Center <-- selected\n'
            '└─▼[/icons/inspector/textArea.png]Text\n'
            '  └─▼[/icons/inspector/textArea.png]RichText\n'),
      );

      await env.tearDownEnvironment();
    });
    */

    // TODO(jacobr): uncomment hotReload test once the hot reload test is not
    // flaky. https://github.com/flutter/devtools/issues/642
    /*
    test('hotReload', () async {
      if (flutterVersion == '1.2.1') {
        // This test can be flaky in Flutter 1.2.1 because of
        // https://github.com/dart-lang/sdk/issues/33838
        // so we just skip it. This block of code can be removed after the next
        // stable flutter release.
        // TODO(dantup): Remove this.
        return;
      }
      await env.setupEnvironment();

      await serviceManager.performHotReload();
      // Ensure the inspector does not fall over and die after a hot reload.
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center\n'
          '      │     [/icons/inspector/textArea.png]Text <-- selected\n'
          '      └─▼[A]AppBar\n'
          '          [/icons/inspector/textArea.png]Text\n',
        ),
      );

      // TODO(jacobr): would be nice to have some tests that trigger a hot
      // reload that actually changes app state in a meaningful way.

      await env.tearDownEnvironment();
    });
    */
    // TODO(jacobr): uncomment out the hotRestart tests once
    // https://github.com/flutter/devtools/issues/337 is fixed.
    /*
    test('hotRestart', () async {
      await env.setupEnvironment();

      // The important thing about this is that the details tree should scroll
      // instead of re-rooting as the selected row is already visible in the
      // details tree.
      simulateRowClick(tree, rowIndex: 4);
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R]root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▼[S]Scaffold\n'
              '      ├───▼[C]Center <-- selected\n'
              '      │     ▼[/icons/inspector/textArea.png]Text\n'
              '      └─▼[A]AppBar\n'
              '          ▼[/icons/inspector/textArea.png]Text\n',
        ),
      );

      /// After the hot restart some existing calls to the vm service may
      /// timeout and that is ok.
      serviceManager.manager.service.doNotWaitForPendingFuturesBeforeExit();

      await serviceManager.performHotRestart();
      // The isolate starts out paused on a hot restart so we have to resume
      // it manually to make the test pass.

      await serviceManager.manager.service
          .resume(serviceManager.isolateManager.selectedIsolate.id);

      // First UI transition is to an empty tree.
      await detailsTree.nextUiFrame;
      expect(tree.toStringDeep(), equalsIgnoringHashCodes('<empty>\n'));

      // Notice that the selection has been lost due to the hot restart.
      await detailsTree.nextUiFrame;
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▼[S]Scaffold\n'
              '      ├───▼[C]Center\n'
              '      │     ▼[/icons/inspector/textArea.png]Text\n'
              '      └─▼[A]AppBar\n'
              '          ▼[/icons/inspector/textArea.png]Text\n',
        ),
      );

      // Verify that the selection can actually be changed after a restart.
      simulateRowClick(tree, rowIndex: 4);
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▼[S]Scaffold\n'
              '      ├───▼[C]Center <-- selected\n'
              '      │     ▼[/icons/inspector/textArea.png]Text\n'
              '      └─▼[A]AppBar\n'
              '          ▼[/icons/inspector/textArea.png]Text\n',
        ),
      );
      await env.tearDownEnvironment();
    });
*/
  });

  group('widget errors', () {
    setUpAll(() async {
      env = FlutterTestEnvironment(
        testAppDirectory: 'test/test_infra/fixtures/inspector_app',
        const FlutterRunConfiguration(withDebugger: true),
      );
      await env.setupEnvironment(
        config: const FlutterRunConfiguration(
          withDebugger: true,
          entryScript: 'lib/overflow_errors.dart',
        ),
      );
      env.afterEverySetup = resetInspectorSelection;
      // Enable the legacy inspector.
      preferences.inspector.setLegacyInspectorEnabled(true);
    });

    testWidgetsWithWindowSize('show navigator and error labels', windowSize, (
      WidgetTester tester,
    ) async {
      expect(serviceConnection.serviceManager.service, equals(env.service));
      expect(serviceConnection.serviceManager.isolateManager, isNotNull);

      final screen = InspectorScreen();
      await tester.pumpWidget(
        wrapWithInspectorControllers(Builder(builder: screen.build)),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final InspectorScreenBodyState state = tester.state(
        find.byType(InspectorScreenBody),
      );
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
          '../../test_infra/goldens/integration_inspector_errors_1_initial_load.png',
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
          '../../test_infra/goldens/integration_inspector_errors_2_error_selected.png',
        ),
      );

      await env.tearDownEnvironment();
    });
  });
}
