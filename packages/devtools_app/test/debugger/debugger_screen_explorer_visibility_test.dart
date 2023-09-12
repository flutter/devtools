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

  late FakeServiceConnectionManager fakeServiceConnection;
  late MockScriptManager scriptManager;
  late MockDebuggerController debuggerController;
  late CodeViewController mockCodeViewController;
  final scripts = [
    ScriptRef(uri: 'package:test/script.dart', id: 'test-script'),
  ];

  group(
    'FileExplorer',
    () {
      setUp(() {
        fakeServiceConnection = FakeServiceConnectionManager();
        scriptManager = MockScriptManager();
        mockConnectedApp(
          fakeServiceConnection.serviceManager.connectedApp!,
          isFlutterApp: true,
          isProfileBuild: false,
          isWebApp: false,
        );
        setGlobal(ServiceConnectionManager, fakeServiceConnection);
        setGlobal(IdeTheme, IdeTheme());
        setGlobal(NotificationService, NotificationService());
        setGlobal(ScriptManager, scriptManager);
        setGlobal(BreakpointManager, BreakpointManager());
        setGlobal(
          DevToolsEnvironmentParameters,
          ExternalDevToolsEnvironmentParameters(),
        );
        setGlobal(PreferencesController, PreferencesController());
        fakeServiceConnection.consoleService.ensureServiceInitialized();
        when(
          fakeServiceConnection.errorBadgeManager
              .errorCountNotifier('debugger'),
        ).thenReturn(ValueNotifier<int>(0));
        final mockProgramExplorerController =
            createMockProgramExplorerControllerWithDefaults();
        mockCodeViewController = createMockCodeViewControllerWithDefaults(
          programExplorerController: mockProgramExplorerController,
        );
        debuggerController = createMockDebuggerControllerWithDefaults(
          codeViewController: mockCodeViewController,
        );

        when(scriptManager.sortedScripts).thenReturn(ValueNotifier(scripts));

        when(mockProgramExplorerController.rootObjectNodes).thenReturn(
          ValueNotifier(
            [
              VMServiceObjectNode(
                mockCodeViewController.programExplorerController,
                'package:test',
                null,
              ),
            ],
          ),
        );
        when(mockCodeViewController.showFileOpener)
            .thenReturn(ValueNotifier(false));
      });

      Future<void> pumpDebuggerScreen(
        WidgetTester tester,
        DebuggerController controller,
      ) async {
        await tester.pumpWidget(
          wrapWithControllers(
            DebuggerSourceAndControls(
              shownFirstScript: () => true,
              setShownFirstScript: (_) {},
            ),
            debugger: controller,
          ),
        );
      }

      testWidgetsWithWindowSize(
        'visible',
        windowSize,
        (WidgetTester tester) async {
          // File Explorer view is shown
          when(mockCodeViewController.fileExplorerVisible)
              .thenReturn(ValueNotifier(true));
          await pumpDebuggerScreen(tester, debuggerController);
          // One for the button and one for the title of the File Explorer view.
          expect(find.text('File Explorer'), findsNWidgets(2));

          // test for items in the libraries tree
          expect(
            find.text(scripts.first.uri!.split('/').first),
            findsOneWidget,
          );
        },
      );

      testWidgetsWithWindowSize(
        'hidden',
        windowSize,
        (WidgetTester tester) async {
          // File Explorer view is hidden
          when(mockCodeViewController.fileExplorerVisible)
              .thenReturn(ValueNotifier(false));
          await pumpDebuggerScreen(tester, debuggerController);
          expect(find.text('File Explorer'), findsOneWidget);
        },
      );
    },
  );
}
