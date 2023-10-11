// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);
  final mockBreakpointManager = MockBreakpointManager();
  final fakeServiceConnection = FakeServiceConnectionManager();
  final scriptManager = MockScriptManager();
  mockConnectedApp(
    fakeServiceConnection.serviceManager.connectedApp!,
    isFlutterApp: true,
    isProfileBuild: false,
    isWebApp: false,
  );
  setGlobal(ServiceConnectionManager, fakeServiceConnection);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  setGlobal(NotificationService, NotificationService());
  setGlobal(BreakpointManager, mockBreakpointManager);
  setGlobal(
    DevToolsEnvironmentParameters,
    ExternalDevToolsEnvironmentParameters(),
  );
  setGlobal(PreferencesController, PreferencesController());
  fakeServiceConnection.consoleService.ensureServiceInitialized();
  when(fakeServiceConnection.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));
  final debuggerController = createMockDebuggerControllerWithDefaults();

  final breakpoints = [
    Breakpoint(
      breakpointNumber: 1,
      id: 'bp1',
      resolved: false,
      location: UnresolvedSourceLocation(
        scriptUri: 'package:test/script.dart',
        line: 10,
      ),
      enabled: true,
    ),
  ];

  final breakpointsWithLocation = [
    BreakpointAndSourcePosition.create(
      breakpoints.first,
      const SourcePosition(line: 10, column: 1),
    ),
  ];
  final codeViewController = debuggerController.codeViewController;
  when(mockBreakpointManager.breakpoints)
      .thenReturn(ValueNotifier(breakpoints));
  when(mockBreakpointManager.breakpointsWithLocation)
      .thenReturn(ValueNotifier(breakpointsWithLocation));

  when(scriptManager.sortedScripts).thenReturn(ValueNotifier([]));
  when(codeViewController.scriptLocation).thenReturn(ValueNotifier(null));
  when(codeViewController.showFileOpener).thenReturn(ValueNotifier(false));

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
    'Breakpoints show items',
    windowSize,
    (WidgetTester tester) async {
      await pumpDebuggerScreen(tester, debuggerController);

      expect(find.text('Breakpoints'), findsOneWidget);

      // test for items in the breakpoint list
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('script.dart:10'),
        ),
        findsOneWidget,
      );
    },
  );
}
