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
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  late FakeServiceManager fakeServiceManager;
  late MockDebuggerController debuggerController;
  late MockScriptManagerLegacy scriptManager;

  const windowSize = Size(4000.0, 4000.0);

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    scriptManager = MockScriptManagerLegacy();
    when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(ScriptManager, scriptManager);
    fakeServiceManager.consoleService.ensureServiceInitialized();
    when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));
    debuggerController = createMockDebuggerControllerWithDefaults();
  });

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

  testWidgetsWithWindowSize('Call Stack shows items', windowSize,
      (WidgetTester tester) async {
    final stackFrames = [
      Frame(
        index: 0,
        code: CodeRef(
          name: 'testCodeRef',
          id: 'testCodeRef',
          kind: CodeKind.kDart,
        ),
        location: SourceLocation(
          script: ScriptRef(uri: 'package:test/script.dart', id: 'script.dart'),
          tokenPos: 10,
        ),
        kind: FrameKind.kRegular,
      ),
      Frame(
        index: 1,
        location: SourceLocation(
          script:
              ScriptRef(uri: 'package:test/script1.dart', id: 'script1.dart'),
          tokenPos: 10,
        ),
        kind: FrameKind.kRegular,
      ),
      Frame(
        index: 2,
        code: CodeRef(
          name: '[Unoptimized] testCodeRef2',
          id: 'testCodeRef2',
          kind: CodeKind.kDart,
        ),
        location: SourceLocation(
          script:
              ScriptRef(uri: 'package:test/script2.dart', id: 'script2.dart'),
          tokenPos: 10,
        ),
        kind: FrameKind.kRegular,
      ),
      Frame(
        index: 3,
        code: CodeRef(
          name: 'testCodeRef3.<anonymous closure>',
          id: 'testCodeRef3.closure',
          kind: CodeKind.kDart,
        ),
        location: SourceLocation(
          script:
              ScriptRef(uri: 'package:test/script3.dart', id: 'script3.dart'),
          tokenPos: 10,
        ),
        kind: FrameKind.kRegular,
      ),
      Frame(
        index: 4,
        location: SourceLocation(
          script:
              ScriptRef(uri: 'package:test/script4.dart', id: 'script4.dart'),
          tokenPos: 10,
        ),
        kind: FrameKind.kAsyncSuspensionMarker,
      ),
    ];

    final stackFramesWithLocation =
        stackFrames.map<StackFrameAndSourcePosition>((frame) {
      return StackFrameAndSourcePosition(
        frame,
        position: SourcePosition(
          line: stackFrames.indexOf(frame),
          column: 10,
        ),
      );
    }).toList();

    when(debuggerController.stackFramesWithLocation)
        .thenReturn(ValueNotifier(stackFramesWithLocation));
    when(debuggerController.isPaused).thenReturn(ValueNotifier(true));
    when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));
    await pumpDebuggerScreen(tester, debuggerController);

    expect(find.text('Call Stack'), findsOneWidget);

    // Stack frame 0
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('testCodeRef script.dart:0'),
      ),
      findsOneWidget,
    );

    // verify that the frame has a tooltip
    expect(
      find.byTooltip('testCodeRef script.dart:0'),
      findsOneWidget,
    );

    // Stack frame 1
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('<none> script1.dart:1'),
      ),
      findsOneWidget,
    );
    // Stack frame 2
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('testCodeRef2 script2.dart:2'),
      ),
      findsOneWidget,
    );
    // Stack frame 3
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText &&
            widget.text
                .toPlainText()
                .contains('testCodeRef3.<closure> script3.dart:3'),
      ),
      findsOneWidget,
    );
    // Stack frame 4
    expect(find.text('<async break>'), findsOneWidget);
  });
}
