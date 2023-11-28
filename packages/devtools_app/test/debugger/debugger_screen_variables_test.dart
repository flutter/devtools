// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/diagnostics/tree_builder.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/utils/variable_utils.dart';

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;
  late MockDebuggerController debuggerController;
  late MockScriptManager scriptManager;

  const windowSize = Size(4000, 4000);

  setUp(() {
    fakeServiceConnection = FakeServiceConnectionManager();
    scriptManager = MockScriptManager();

    mockConnectedApp(
      fakeServiceConnection.serviceManager.connectedApp!,
      isProfileBuild: false,
      isFlutterApp: true,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, scriptManager);
    setGlobal(NotificationService, NotificationService());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    fakeServiceConnection.consoleService.ensureServiceInitialized();
    when(fakeServiceConnection.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));
    debuggerController = createMockDebuggerControllerWithDefaults();

    resetRef();
    resetRoot();
  });

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DebuggerWindows(),
        debugger: controller,
      ),
    );
  }

  Future<void> verifyGroupings(
    WidgetTester tester, {
    required Finder parentFinder,
  }) async {
    final group0To9999Finder = find.textContaining('[0 - 9999]');
    final group10000To19999Finder = find.textContaining('[10000 - 19999]');
    final group230000To239999Finder = find.textContaining('[230000 - 239999]');
    final group240000To243620Finder = find.textContaining('[240000 - 243620]');

    final group0To99Finder = find.textContaining('[0 - 99]');
    final group100To199Finder = find.textContaining('[100 - 199]');
    final group200To299Finder = find.textContaining('[200 - 299]');

    // Initially the parent variable is not expanded.
    expect(parentFinder, findsOneWidget);
    expect(group0To9999Finder, findsNothing);
    expect(group10000To19999Finder, findsNothing);
    expect(group230000To239999Finder, findsNothing);
    expect(group240000To243620Finder, findsNothing);

    // Expand the parent variable.
    await tester.tap(parentFinder);
    await tester.pump();
    expect(group0To9999Finder, findsOneWidget);
    expect(group10000To19999Finder, findsOneWidget);
    expect(group230000To239999Finder, findsOneWidget);
    expect(group240000To243620Finder, findsOneWidget);

    // Initially group [0 - 9999] is not expanded.
    expect(group0To99Finder, findsNothing);
    expect(group100To199Finder, findsNothing);
    expect(group200To299Finder, findsNothing);

    // Expand group [0 - 9999].
    await tester.tap(group0To9999Finder);
    await tester.pump();
    expect(group0To99Finder, findsOneWidget);
    expect(group100To199Finder, findsOneWidget);
    expect(group200To299Finder, findsOneWidget);
  }

  testWidgetsWithWindowSize(
    'Variables shows items',
    windowSize,
    (WidgetTester tester) async {
      fakeServiceConnection.appState.setVariables(
        [
          buildListVariable(),
          buildMapVariable(),
          buildStringVariable('test str'),
          buildBooleanVariable(true),
          buildSetVariable(),
        ],
      );
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Variables'), findsOneWidget);

      final listFinder = find.text('Root 1: List (2 items)');

      expect(listFinder, findsOneWidget);

      final mapFinder = find.textContaining(
        'Root 2: Map (2 items)',
      );
      final mapElement1Finder = find.textContaining("['key1']: 1.0");
      final mapElement2Finder = find.textContaining("['key2']: 2.0");

      expect(listFinder, findsOneWidget);
      expect(mapFinder, findsOneWidget);
      expect(
        find.textContaining("Root 3: 'test str...'"),
        findsOneWidget,
      );
      expect(
        find.textContaining('Root 4: true'),
        findsOneWidget,
      );

      // Initially list is not expanded.
      expect(find.textContaining('0: 3'), findsNothing);
      expect(find.textContaining('1: 4'), findsNothing);

      // Expand list.
      await tester.tap(listFinder);
      await tester.pump();
      expect(find.textContaining('0: 0'), findsOneWidget);
      expect(find.textContaining('1: 1'), findsOneWidget);

      // Initially map is not expanded.
      expect(mapElement1Finder, findsNothing);
      expect(mapElement2Finder, findsNothing);

      // Expand map.
      await tester.tap(mapFinder);
      await tester.pump();
      expect(mapElement1Finder, findsOneWidget);
      expect(mapElement2Finder, findsOneWidget);

      // Expect a tooltip for the set instance.
      final setFinder = find.text('Root 5: Set (2 items)');
      expect(setFinder, findsOneWidget);

      // Initially set is not expanded.
      expect(find.textContaining('set value 0'), findsNothing);
      expect(find.textContaining('set value 1'), findsNothing);

      // Expand set
      await tester.tap(setFinder);
      await tester.pump();
      expect(find.textContaining('set value 0'), findsOneWidget);
      expect(find.textContaining('set value 1'), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'Children in large list variables are grouped',
    windowSize,
    (WidgetTester tester) async {
      final list = buildParentListVariable(length: 243621);
      await buildVariablesTree(list);

      final appState = serviceConnection.appState;
      appState.setVariables([list]);

      await pumpDebuggerScreen(tester, debuggerController);

      final listFinder = find.text('Root 1: List (243,621 items)');
      await verifyGroupings(tester, parentFinder: listFinder);
    },
  );

  testWidgetsWithWindowSize(
    'Children in large map variables are grouped',
    windowSize,
    (WidgetTester tester) async {
      final map = buildParentMapVariable(length: 243621);
      await buildVariablesTree(map);

      final appState = serviceConnection.appState;
      appState.setVariables([map]);

      await pumpDebuggerScreen(tester, debuggerController);

      final mapFinder = find.text('Root 1: Map (243,621 items)');
      await verifyGroupings(tester, parentFinder: mapFinder);
    },
  );

  testWidgetsWithWindowSize(
    'Children in large set variables are grouped',
    windowSize,
    (WidgetTester tester) async {
      final set = buildParentSetVariable(length: 243621);
      await buildVariablesTree(set);

      final appState = serviceConnection.appState;
      appState.setVariables([set]);

      await pumpDebuggerScreen(tester, debuggerController);

      final setFinder = find.text('Root 1: Set (243,621 items)');
      await verifyGroupings(tester, parentFinder: setFinder);
    },
  );
}
