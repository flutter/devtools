// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);
  final fakeServiceManager = FakeServiceManager();
  final scriptManager = MockScriptManager();
  mockConnectedApp(
    fakeServiceManager.connectedApp!,
    isProfileBuild: false,
    isFlutterApp: true,
    isWebApp: false,
  );
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  setGlobal(NotificationService, NotificationService());
  setGlobal(BreakpointManager, BreakpointManager());
  setGlobal(
    DevToolsEnvironmentParameters,
    ExternalDevToolsEnvironmentParameters(),
  );
  setGlobal(PreferencesController, PreferencesController());
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));
  final debuggerController = createMockDebuggerControllerWithDefaults();
  final codeViewController = debuggerController.codeViewController;

  final scripts = [
    ScriptRef(uri: 'package:/test/script.dart', id: 'test-script'),
  ];

  when(scriptManager.sortedScripts).thenReturn(ValueNotifier(scripts));
  when(codeViewController.showFileOpener).thenReturn(ValueNotifier(false));
  when(codeViewController.showProfileInformation).thenReturn(
    const FixedValueListenable(false),
  );

  // File Explorer view is hidden
  when(codeViewController.fileExplorerVisible).thenReturn(ValueNotifier(false));

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

  testWidgetsWithWindowSize(
    'File Explorer hidden',
    windowSize,
    (WidgetTester tester) async {
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('File Explorer'), findsOneWidget);
    },
  );
}
