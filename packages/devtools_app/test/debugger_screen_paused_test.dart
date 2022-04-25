// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/controls.dart';
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
  const screen = DebuggerScreen();
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
  final debuggerController = createMockDebuggerControllerWithDefaults();
  when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));

  WidgetPredicate createDebuggerButtonPredicate(String title) {
    return (Widget widget) {
      if (widget is DebuggerButton && widget.title == title) {
        return true;
      }
      return false;
    };
  }

  testWidgetsWithWindowSize('debugger controls paused', windowSize,
      (WidgetTester tester) async {
    when(debuggerController.isPaused).thenReturn(ValueNotifier(true));
    when(debuggerController.stackFramesWithLocation).thenReturn(
      ValueNotifier([
        StackFrameAndSourcePosition(
          Frame(
            index: 0,
            code: CodeRef(
              name: 'testCodeRef',
              id: 'testCodeRef',
              kind: CodeKind.kDart,
            ),
            location: SourceLocation(
              script: ScriptRef(
                uri: 'package:test/script.dart',
                id: 'script.dart',
              ),
              tokenPos: 10,
            ),
            kind: FrameKind.kRegular,
          ),
          position: const SourcePosition(
            line: 1,
            column: 10,
          ),
        )
      ]),
    );

    await tester.pumpWidget(
      wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ),
    );

    expect(
      find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')),
      findsOneWidget,
    );
    final pause = _getWidgetFromFinder(
      find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')),
    ) as DebuggerButton;
    expect(pause.onPressed, isNull);

    expect(
      find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
      findsOneWidget,
    );
    final resume = _getWidgetFromFinder(
      find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
    ) as DebuggerButton;
    expect(resume.onPressed, isNotNull);
  });
}

Widget _getWidgetFromFinder(Finder finder) {
  return finder.first.evaluate().first.widget;
}
