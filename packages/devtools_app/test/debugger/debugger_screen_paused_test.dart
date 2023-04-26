// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/screens/debugger/controls.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  final screen = DebuggerScreen();

  const windowSize = Size(2500.0, 1500.0);

  final fakeServiceManager = FakeServiceManager();
  final scriptManager = MockScriptManager();
  mockConnectedApp(
    fakeServiceManager.connectedApp!,
    isFlutterApp: true,
    isProfileBuild: false,
    isWebApp: false,
  );
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  setGlobal(NotificationService, NotificationService());
  setGlobal(BreakpointManager, BreakpointManager());
  setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
  setGlobal(PreferencesController, PreferencesController());
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));
  final debuggerController = createMockDebuggerControllerWithDefaults();
  final codeViewController = debuggerController.codeViewController;
  final scriptsHistory = ScriptsHistory();
  scriptsHistory.pushEntry(mockScript!);
  when(codeViewController.scriptsHistory).thenReturn(scriptsHistory);

  when(debuggerController.stackFramesWithLocation).thenReturn(
    ValueNotifier([
      _firstStackFrame,
      _secondStackFrame,
    ]),
  );
  when(debuggerController.selectedStackFrame).thenReturn(ValueNotifier(null));

  WidgetPredicate createDebuggerButtonPredicate(String title) {
    return (Widget widget) {
      if (widget is DebuggerButton && widget.title == title) {
        return true;
      }
      return false;
    };
  }

  Finder findStackFrameWithText(String text) => find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText && widget.text.toPlainText().contains(text),
      );

  testWidgetsWithWindowSize(
    'debugger controls paused',
    windowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.build),
          debugger: debuggerController,
        ),
      );
      (serviceManager.isolateManager as FakeIsolateManager)
          .setMainIsolatePausedState(true);
      await tester.pump();

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
    },
  );

  testWidgetsWithWindowSize(
    'figure out test name',
    windowSize,
    (WidgetTester tester) async {
      when(codeViewController.currentScriptRef)
          .thenReturn(ValueNotifier(mockScriptRef));
      when(codeViewController.scriptLocation)
          .thenReturn(ValueNotifier(_firstScriptLocation));
      when(codeViewController.currentParsedScript)
          .thenReturn(ValueNotifier(mockParsedScript));

      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.build),
          debugger: debuggerController,
        ),
      );
      (serviceManager.isolateManager as FakeIsolateManager)
          .setMainIsolatePausedState(true);
      await tester.pump();

      // The first stack frame is visible:
      final firstStackFrame =
          findStackFrameWithText('firstCodeRef 17b557e5bc3:40');
      expect(firstStackFrame, isNotNull);
      // The first stack frame's line is visible:
      final firstStackFrameLine =
          find.widgetWithText(GutterItem, '$_firstLineNumber');
      expect(firstStackFrameLine, isNotNull);

      // The second stack frame is visible:
      final secondStackFrame =
          findStackFrameWithText('secondCodeRef 17b557e5bc3:40');
      expect(secondStackFrame, isNotNull);

      // The second stack frame's line is not visible:
      // final secondStackFrameLine =
      //     find.widgetWithText(GutterItem, '$_secondLineNumber');
      // expect(secondStackFrameLine, isNull);

      final gutterItems = find.byType(GutterItem);
      print(gutterItems);
      expect(gutterItems, findsNWidgets(200));


      // Click on the second stack frame:

      // The second stack frame's line is now visible:

      // The first stack frame's line is not visible:
    },
  );
}

Widget _getWidgetFromFinder(Finder finder) {
  return finder.first.evaluate().first.widget;
}

const _firstLineNumber = 40;

const _firstSourcePosition = SourcePosition(line: _firstLineNumber, column: 1);

final _firstScriptLocation = ScriptLocation(
  mockScriptRef,
  location: _firstSourcePosition,
);

final _firstStackFrame = StackFrameAndSourcePosition(
  Frame(
    index: 0,
    code: CodeRef(
      name: 'firstCodeRef',
      id: 'firstCodeRef',
      kind: CodeKind.kDart,
    ),
    location: SourceLocation(
      script: mockScriptRef,
    ),
    kind: FrameKind.kRegular,
  ),
  position: _firstSourcePosition,
);

const _secondLineNumber = 200;

const _secondSourcePosition =
    SourcePosition(line: _secondLineNumber, column: 1);

final _secondScriptLocation = ScriptLocation(
  mockScriptRef,
  location: _secondSourcePosition,
);

final _secondStackFrame = StackFrameAndSourcePosition(
  Frame(
    index: 1,
    code: CodeRef(
      name: 'secondCodeRef',
      id: 'secondCodeRef',
      kind: CodeKind.kDart,
    ),
    location: SourceLocation(
      script: mockScriptRef,
    ),
    kind: FrameKind.kRegular,
  ),
  position: _secondSourcePosition,
);
