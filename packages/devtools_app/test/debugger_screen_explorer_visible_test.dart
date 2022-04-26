// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer_model.dart';
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
  final scriptManager = MockScriptManagerLegacy();
  when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
  when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));
  final mockProgramExplorerController =
      createMockProgramExplorerControllerWithDefaults();
  final debuggerController = createMockDebuggerControllerWithDefaults(
    mockProgramExplorerController: mockProgramExplorerController,
  );
  final scripts = [
    ScriptRef(uri: 'package:test/script.dart', id: 'test-script')
  ];

  when(scriptManager.sortedScripts).thenReturn(ValueNotifier(scripts));

  when(mockProgramExplorerController.rootObjectNodes).thenReturn(
    ValueNotifier(
      [
        VMServiceObjectNode(
          debuggerController.programExplorerController,
          'package:test',
          null,
        ),
      ],
    ),
  );
  when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));

  // File Explorer view is shown
  when(debuggerController.fileExplorerVisible).thenReturn(ValueNotifier(true));

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

  testWidgetsWithWindowSize('File Explorer visible', windowSize,
      (WidgetTester tester) async {
    await pumpDebuggerScreen(tester, debuggerController);
    // One for the button and one for the title of the File Explorer view.
    expect(find.text('File Explorer'), findsNWidgets(2));

    // test for items in the libraries tree
    expect(find.text(scripts.first.uri!.split('/').first), findsOneWidget);
  });
}
