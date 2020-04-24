// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/flutter/controls.dart';
import 'package:devtools_app/src/debugger/flutter/debugger_controller.dart';
import 'package:devtools_app/src/debugger/flutter/debugger_model.dart';
import 'package:devtools_app/src/debugger/flutter/debugger_screen.dart';
import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  DebuggerScreen screen;
  FakeServiceManager fakeServiceManager;
  MockDebuggerController debuggerController;

  group('DebuggerScreen', () {
    Future<void> pumpDebuggerScreen(
        WidgetTester tester, DebuggerController controller) async {
      await tester.pumpWidget(wrapWithControllers(
        const DebuggerScreenBody(),
        debugger: controller,
      ));
    }

    setUp(() async {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);

      screen = const DebuggerScreen();

      debuggerController = MockDebuggerController();
      when(debuggerController.isPaused).thenReturn(ValueNotifier(false));
      when(debuggerController.hasFrames).thenReturn(ValueNotifier(false));
      when(debuggerController.breakpoints).thenReturn(ValueNotifier([]));
      when(debuggerController.breakpointsWithLocation)
          .thenReturn(ValueNotifier([]));
      when(debuggerController.librariesVisible)
          .thenReturn(ValueNotifier(false));
      when(debuggerController.currentScriptRef).thenReturn(ValueNotifier(null));
      when(debuggerController.sortedScripts).thenReturn(ValueNotifier([]));
      when(debuggerController.sortedClasses).thenReturn(ValueNotifier([]));
      when(debuggerController.selectedBreakpoint)
          .thenReturn(ValueNotifier(null));
      when(debuggerController.stackFramesWithLocation)
          .thenReturn(ValueNotifier([]));
      when(debuggerController.selectedStackFrame)
          .thenReturn(ValueNotifier(null));
      when(debuggerController.stdio).thenReturn(ValueNotifier(['']));
      when(debuggerController.scriptLocation).thenReturn(ValueNotifier(null));
      when(debuggerController.exceptionPauseMode)
          .thenReturn(ValueNotifier('Unhandled'));
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Debugger'), findsOneWidget);
    });

    testWidgets('builds disabled message when disabled for profile mode',
        (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(true);
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(DebuggerScreenBody), findsNothing);
      expect(find.byType(DisabledForProfileBuildMessage), findsOneWidget);
    });

    testWidgets('has Console area', (WidgetTester tester) async {
      when(debuggerController.stdio).thenReturn(ValueNotifier(['test stdio']));

      await pumpDebuggerScreen(tester, debuggerController);

      expect(find.text('Console'), findsOneWidget);

      // test for stdio output.
      expect(find.text('test stdio'), findsOneWidget);
    });

    testWidgets('Libraries hidden', (WidgetTester tester) async {
      final scripts = [ScriptRef(uri: 'package:/test/script.dart')];

      when(debuggerController.sortedScripts).thenReturn(ValueNotifier(scripts));

      // Libraries view is hidden
      when(debuggerController.librariesVisible)
          .thenReturn(ValueNotifier(false));
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Libraries and Classes'), findsNothing);
    });

    testWidgets('Libraries visible', (WidgetTester tester) async {
      final scripts = [ScriptRef(uri: 'package:/test/script.dart')];
      final classes = [ClassRef(name: 'Foo')];

      when(debuggerController.sortedScripts).thenReturn(ValueNotifier(scripts));
      when(debuggerController.sortedClasses).thenReturn(ValueNotifier(classes));

      // Libraries view is shown
      when(debuggerController.librariesVisible).thenReturn(ValueNotifier(true));
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Libraries and Classes'), findsOneWidget);

      // test for items in the libraries and classes list
      expect(find.text(scripts.first.uri), findsOneWidget);
      expect(find.text(classes.first.name), findsOneWidget);
    });

    testWidgets('Breakpoints show items', (WidgetTester tester) async {
      final breakpoints = [
        Breakpoint(
          breakpointNumber: 1,
          resolved: false,
          location: UnresolvedSourceLocation(
            scriptUri: 'package:/test/script.dart',
            line: 10,
          ),
        )
      ];

      final breakpointsWithLocation = [
        BreakpointAndSourcePosition.create(
          breakpoints.first,
          SourcePosition(line: 10, column: 1),
        )
      ];

      when(debuggerController.breakpoints)
          .thenReturn(ValueNotifier(breakpoints));
      when(debuggerController.breakpointsWithLocation)
          .thenReturn(ValueNotifier(breakpointsWithLocation));

      when(debuggerController.sortedScripts).thenReturn(ValueNotifier([]));
      when(debuggerController.stdio).thenReturn(ValueNotifier([]));
      when(debuggerController.scriptLocation).thenReturn(ValueNotifier(null));

      await pumpDebuggerScreen(tester, debuggerController);

      expect(find.text('Breakpoints'), findsOneWidget);

      // test for items in the breakpoint list
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('script.dart:10')),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize(
        'call stack show items', const Size(1000.0, 4000.0),
        (WidgetTester tester) async {
      final stackFrames = [
        Frame(
          index: 0,
          code: CodeRef(name: 'testCodeRef', kind: CodeKind.kDart),
          location: SourceLocation(
            script: ScriptRef(uri: 'package:/test/script.dart'),
            tokenPos: 10,
          ),
          kind: FrameKind.kRegular,
        ),
        Frame(
          index: 1,
          location: SourceLocation(
            script: ScriptRef(uri: 'package:/test/script1.dart'),
            tokenPos: 10,
          ),
          kind: FrameKind.kRegular,
        ),
        Frame(
          index: 2,
          code: CodeRef(
            name: '[Unoptimized] testCodeRef2',
            kind: CodeKind.kDart,
          ),
          location: SourceLocation(
            script: ScriptRef(uri: 'package:/test/script2.dart'),
            tokenPos: 10,
          ),
          kind: FrameKind.kRegular,
        ),
        Frame(
          index: 3,
          code: CodeRef(
            name: 'testCodeRef3.<anonymous closure>',
            kind: CodeKind.kDart,
          ),
          location: SourceLocation(
            script: ScriptRef(uri: 'package:/test/script3.dart'),
            tokenPos: 10,
          ),
          kind: FrameKind.kRegular,
        ),
        Frame(
          index: 4,
          location: SourceLocation(
            script: ScriptRef(uri: 'package:/test/script4.dart'),
            tokenPos: 10,
          ),
          kind: FrameKind.kAsyncSuspensionMarker,
        ),
      ];

      final stackFramesWithLocation =
          stackFrames.map<StackFrameAndSourcePosition>((frame) {
        return StackFrameAndSourcePosition.create(
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
      await pumpDebuggerScreen(tester, debuggerController);

      expect(find.text('Call Stack'), findsOneWidget);

      // Stack frame 0
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('testCodeRef() script.dart:0')),
        findsOneWidget,
      );
      // Stack frame 1
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('<none> script1.dart:1')),
        findsOneWidget,
      );
      // Stack frame 2
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text
                .toPlainText()
                .contains('testCodeRef2() script2.dart:2')),
        findsOneWidget,
      );
      // Stack frame 3
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text
                .toPlainText()
                .contains('testCodeRef3.<closure>() script3.dart:3')),
        findsOneWidget,
      );
      // Stack frame 4
      expect(find.text('<async break>'), findsOneWidget);
    });

    WidgetPredicate createDebuggerButtonPredicate(String title) {
      return (Widget widget) {
        if (widget is DebuggerButton && widget.title == title) {
          return true;
        }
        return false;
      };
    }

    testWidgets('debugger controls running', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ));

      expect(find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')),
          findsOneWidget);
      final DebuggerButton pause = getWidgetFromFinder(
          find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')));
      expect(pause.onPressed, isNotNull);

      expect(find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
          findsOneWidget);
      final DebuggerButton resume = getWidgetFromFinder(
          find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')));
      expect(resume.onPressed, isNull);
    });

    testWidgets('debugger controls paused', (WidgetTester tester) async {
      when(debuggerController.isPaused).thenReturn(ValueNotifier(true));
      when(debuggerController.hasFrames).thenReturn(ValueNotifier(true));

      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ));

      expect(find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')),
          findsOneWidget);
      final DebuggerButton pause = getWidgetFromFinder(
          find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')));
      expect(pause.onPressed, isNull);

      expect(find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
          findsOneWidget);
      final DebuggerButton resume = getWidgetFromFinder(
          find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')));
      expect(resume.onPressed, isNotNull);
    });

    testWidgets('debugger controls break on exceptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ));
      expect(find.text('Ignore'), findsOneWidget);
    });
  });
}

Widget getWidgetFromFinder(Finder finder) {
  return finder.first.evaluate().first.widget;
}
