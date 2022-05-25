// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
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

import '../matchers/matchers.dart';

void main() {
  final fakeServiceManager = FakeServiceManager();
  final debuggerController = createMockDebuggerControllerWithDefaults();
  final scriptsHistory = ScriptsHistory();

  const smallWindowSize = Size(1000.0, 1000.0);

  when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
  when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, MockScriptManager());
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));

  scriptsHistory.pushEntry(mockScript!);
  when(debuggerController.currentScriptRef)
      .thenReturn(ValueNotifier(mockScriptRef));
  when(debuggerController.currentParsedScript)
      .thenReturn(ValueNotifier(mockParsedScript));
  when(debuggerController.showSearchInFileField)
      .thenReturn(ValueNotifier(false));
  when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));
  when(debuggerController.scriptsHistory).thenReturn(scriptsHistory);
  when(debuggerController.searchMatches).thenReturn(ValueNotifier([]));
  when(debuggerController.activeSearchMatch).thenReturn(ValueNotifier(null));

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
      'has a horizontal and a vertical scrollbar', smallWindowSize,
      (WidgetTester tester) async {
    await pumpDebuggerScreen(tester, debuggerController);

    // TODO(elliette): https://github.com/flutter/flutter/pull/88152 fixes
    // this so that forcing a scroll event is no longer necessary. Remove
    // once the change is in the stable release.
    debuggerController.showScriptLocation(
      ScriptLocation(
        mockScriptRef,
        location: const SourcePosition(line: 50, column: 50),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollbar), findsNWidgets(2));
    expect(
      find.byKey(const Key('debuggerCodeViewVerticalScrollbarKey')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('debuggerCodeViewHorizontalScrollbarKey')),
      findsOneWidget,
    );
    await expectLater(
      find.byKey(DebuggerScreenBody.codeViewKey),
      matchesDevToolsGolden('../goldens/codeview_scrollbars.png'),
    );
  });

  testWidgetsWithWindowSize('can copy the filename', Size(2500.0, 2500.0),
      (WidgetTester tester) async {
    //ScriptPopupMenu
    await pumpDebuggerScreen(tester, debuggerController);

    final menuButton = find.descendant(
      of: find.byType(ScriptPopupMenu),
      matching: find.byType(Tooltip),
    );
    print('DAKE: menuButton');
    print(menuButton);
    expect(menuButton, findsOneWidget);
    await tester.tap(
      menuButton,
    );
    await tester.pumpAndSettle();
    await tester.pump();
    // debugDumpApp();
    expect(find.byType(PopupMenuItem), findsWidgets);
    // await tester.tap();
  });
  testWidgetsWithWindowSize(
      'can copy the package', smallWindowSize, (WidgetTester test) async {});
}
