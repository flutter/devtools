// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:codicon/codicon.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/utils/debugger_utils.dart';
import '../test_infra/utils/test_utils.dart';

void main() {
  const windowSize = Size(2500.0, 1500.0);

  late FakeServiceConnectionManager fakeServiceConnection;
  late MockScriptManager scriptManager;
  late MockDebuggerController debuggerController;

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
    setGlobal(ScriptManager, scriptManager);
    setGlobal(NotificationService, NotificationService());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    fakeServiceConnection.consoleService.ensureServiceInitialized();
    when(fakeServiceConnection.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));
    debuggerController = createMockDebuggerControllerWithDefaults();
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
  });

  Future<void> pumpDebuggerScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        DebuggerScreenBody(
          shownFirstScript: () => true,
          setShownFirstScript: (_) {},
        ),
        debugger: debuggerController,
      ),
    );
  }

  testWidgetsWithWindowSize(
    'debugger controls paused',
    windowSize,
    (WidgetTester tester) async {
      await pumpDebuggerScreen(tester);

      (serviceConnection.serviceManager.isolateManager as FakeIsolateManager)
          .setMainIsolatePausedState(true);
      await tester.pump();

      expect(
        findDebuggerButtonWithIcon(Codicons.debugPause),
        findsOneWidget,
      );
      final pause = getWidgetFromFinder<OutlinedButton>(
        findDebuggerButtonWithIcon(Codicons.debugPause),
      );
      expect(pause.onPressed, isNull);

      expect(
        findDebuggerButtonWithIcon(Codicons.debugContinue),
        findsOneWidget,
      );
      final resume = getWidgetFromFinder<OutlinedButton>(
        findDebuggerButtonWithIcon(Codicons.debugContinue),
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

      await pumpDebuggerScreen(tester);
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
