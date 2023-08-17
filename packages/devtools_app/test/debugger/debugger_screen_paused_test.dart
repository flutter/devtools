// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/screens/debugger/controls.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/utils/test_utils.dart';

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
  final scriptsHistory = ScriptsHistory();
  scriptsHistory.pushEntry(mockScript!);
  when(codeViewController.scriptsHistory).thenReturn(scriptsHistory);
  when(debuggerController.stackFramesWithLocation).thenReturn(
    ValueNotifier([
      _stackFrame1,
      _stackFrame2,
    ]),
  );
  when(codeViewController.currentScriptRef)
      .thenReturn(ValueNotifier(mockScriptRef));
  when(codeViewController.currentParsedScript)
      .thenReturn(ValueNotifier(mockParsedScript));
  when(codeViewController.navigationInProgress).thenReturn(false);

  Finder findDebuggerButtonWithTitle(String title) => find.byWidgetPredicate(
        (Widget widget) => widget is DebuggerButton && widget.title == title,
      );

  Finder findStackFrameWithText(String text) => find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText && widget.text.toPlainText().contains(text),
      );

  bool gutterItemForLineIsVisible(int lineNumber) {
    final gutterItems = find.byType(GutterItem);
    final firstGutterItem = getWidgetFromFinder<GutterItem>(gutterItems.first);
    final lastGutterItem = getWidgetFromFinder<GutterItem>(gutterItems.last);
    final lineRange =
        Range(firstGutterItem.lineNumber, lastGutterItem.lineNumber);

    return lineRange.contains(lineNumber);
  }

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
        findDebuggerButtonWithTitle('Pause'),
        findsOneWidget,
      );
      final pause = getWidgetFromFinder<DebuggerButton>(
        findDebuggerButtonWithTitle('Pause'),
      );
      expect(pause.onPressed, isNull);

      expect(
        findDebuggerButtonWithTitle('Resume'),
        findsOneWidget,
      );
      final resume = getWidgetFromFinder<DebuggerButton>(
        findDebuggerButtonWithTitle('Resume'),
      );
      expect(resume.onPressed, isNotNull);
    },
  );

  testWidgetsWithWindowSize(
    'selecting stackframe scrolls the frame location into view',
    windowSize,
    (WidgetTester tester) async {
      final stackFrameNotifier = ValueNotifier(_stackFrame1);
      when(debuggerController.selectedStackFrame)
          .thenReturn(stackFrameNotifier);

      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.build),
          debugger: debuggerController,
        ),
      );
      await tester.pumpAndSettle();

      // The first stack frame is visible:
      final firstStackFrame =
          findStackFrameWithText('firstCodeRef main.dart:1');
      expect(firstStackFrame, findsOneWidget);

      // The second stack frame is visible:
      final secondStackFrame =
          findStackFrameWithText('secondCodeRef main.dart:85');
      expect(secondStackFrame, findsOneWidget);

      // The first stack frame's line is visible:
      expect(gutterItemForLineIsVisible(_stackFrame1Line), isTrue);

      // The second stack frame's line is not visible:
      expect(gutterItemForLineIsVisible(_stackFrame2Line), isFalse);

      // Update the selected stack frame:
      stackFrameNotifier.value = _stackFrame2;
      await tester.pumpAndSettle();

      // The second stack frame's line is now visible:
      expect(gutterItemForLineIsVisible(_stackFrame2Line), isTrue);

      // The first stack frame's line is not visible:
      expect(gutterItemForLineIsVisible(_stackFrame1Line), isFalse);
    },
  );
}

const _stackFrame1Line = 1;

final _stackFrame1 = StackFrameAndSourcePosition(
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
  position: const SourcePosition(line: _stackFrame1Line, column: 1),
);

const _stackFrame2Line = 85;

final _stackFrame2 = StackFrameAndSourcePosition(
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
  position: const SourcePosition(line: _stackFrame2Line, column: 1),
);
