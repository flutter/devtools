// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dap/dap.dart' as dap;
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/diagnostics/dap_object_node.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;
  late MockDebuggerController debuggerController;
  late MockScriptManager scriptManager;
  late MockVmServiceWrapper vmService;

  const windowSize = Size(2500, 1500);

  setUp(() {
    FeatureFlags.dapDebugging = true;
    vmService = createMockVmServiceWrapperWithDefaults();
    fakeServiceConnection = FakeServiceConnectionManager(service: vmService);
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
  });

  tearDown(() {
    fakeServiceConnection.appState.setDapVariables(
      [],
    );
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

  testWidgetsWithWindowSize(
    'Shows non-expandable variables',
    windowSize,
    (WidgetTester tester) async {
      final node = DapObjectNode(
        service: vmService,
        variable: dap.Variable(
          name: 'myInt',
          value: '10',
          variablesReference: 0,
        ),
      );

      fakeServiceConnection.appState.setDapVariables(
        [node],
      );
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Variables'), findsOneWidget);

      // Variables should include the int.
      final intFinder = find.text('myInt: 10');
      expect(intFinder, findsOneWidget);

      // The int is not expandable.
      final expandArrowFinder = find.byIcon(Icons.keyboard_arrow_down);
      expect(expandArrowFinder, findsNothing);
    },
  );

  testWidgetsWithWindowSize(
    'Shows expandable variables',
    windowSize,
    (WidgetTester tester) async {
      when(vmService.dapVariablesRequest(any)).thenAnswer((_) async {
        return dap.VariablesResponseBody(
          variables: [
            dap.Variable(
              name: 'myString',
              value: '"myString"',
              variablesReference: 0,
            ),
          ],
        );
      });

      final node = DapObjectNode(
        service: vmService,
        variable: dap.Variable(
          name: 'myList',
          value: 'List (1 item)',
          variablesReference: 1,
        ),
      );
      await node.fetchChildren();

      fakeServiceConnection.appState.setDapVariables(
        [node],
      );
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Variables'), findsOneWidget);

      // Variables should include the list.
      final listFinder = find.text('myList: List (1 item)');
      expect(listFinder, findsOneWidget);

      // Initially the string is not visible.
      final stringFinder = find.text('myString: "myString"');
      expect(stringFinder, findsNothing);

      // Expand the list.
      final expandArrowFinder = find.byIcon(Icons.keyboard_arrow_down);
      expect(expandArrowFinder, findsOneWidget);
      await tester.tap(expandArrowFinder.first);
      await tester.pump();

      // String is now visible.
      expect(stringFinder, findsOneWidget);
    },
  );
}
