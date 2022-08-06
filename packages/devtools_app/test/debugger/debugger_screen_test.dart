// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/console.dart';
import 'package:devtools_app/src/screens/debugger/controls.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  const screen = DebuggerScreen();

  const windowSize = Size(4000.0, 4000.0);
  const smallWindowSize = Size(1100.0, 1100.0);

  final fakeServiceManager = FakeServiceManager();
  final scriptManager = MockScriptManager();
  when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
  when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  setGlobal(NotificationService, NotificationService());
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));
  final debuggerController = createMockDebuggerControllerWithDefaults();
  when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));

  Future<void> pumpConsole(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        Row(
          children: [
            Flexible(child: DebuggerConsole.buildHeader()),
            const Expanded(child: DebuggerConsole()),
          ],
        ),
        debugger: controller,
      ),
    );
  }

  testWidgets('builds its tab', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
    expect(find.text('Debugger'), findsOneWidget);
  });

  testWidgetsWithWindowSize('has Console / stdio area', windowSize,
      (WidgetTester tester) async {
    serviceManager.consoleService.appendStdio('test stdio');

    await pumpConsole(tester, debuggerController);

    expect(find.text('Console'), findsOneWidget);

    // test for stdio output.
    expect(find.selectableText('test stdio'), findsOneWidget);
  });

  WidgetPredicate createDebuggerButtonPredicate(String title) {
    return (Widget widget) {
      if (widget is DebuggerButton && widget.title == title) {
        return true;
      }
      return false;
    };
  }

  testWidgetsWithWindowSize('debugger controls running', windowSize,
      (WidgetTester tester) async {
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
    expect(pause.onPressed, isNotNull);

    expect(
      find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
      findsOneWidget,
    );
    final resume = _getWidgetFromFinder(
      find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
    ) as DebuggerButton;
    expect(resume.onPressed, isNull);
  });

  testWidgetsWithWindowSize('debugger controls break on exceptions', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ),
    );
    expect(find.text("Don't stop on exceptions"), findsOneWidget);
  });

  testWidgetsWithWindowSize(
      'debugger controls break on exceptions abbreviated on small window',
      smallWindowSize, (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ),
    );
    expect(find.text('Ignore exceptions'), findsOneWidget);
  });
}

Widget _getWidgetFromFinder(Finder finder) {
  return finder.first.evaluate().first.widget;
}
