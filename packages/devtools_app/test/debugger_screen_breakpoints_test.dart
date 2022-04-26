// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);

  final fakeServiceManager = FakeServiceManager();
  final scriptManager = MockScriptManager();
  when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
  when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
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
    )
  ];

  final breakpointsWithLocation = [
    BreakpointAndSourcePosition.create(
      breakpoints.first,
      const SourcePosition(line: 10, column: 1),
    )
  ];

  when(debuggerController.breakpoints).thenReturn(ValueNotifier(breakpoints));
  when(debuggerController.breakpointsWithLocation)
      .thenReturn(ValueNotifier(breakpointsWithLocation));

  when(scriptManager.sortedScripts).thenReturn(ValueNotifier([]));
  when(debuggerController.scriptLocation).thenReturn(ValueNotifier(null));
  when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DebuggerScreenBody(),
        debugger: controller,
      ),
    );
  }

  testWidgetsWithWindowSize('Breakpoints show items', windowSize,
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
  });
}
