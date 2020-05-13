// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/src/debugger/flutter/console.dart';
import 'package:devtools_app/src/debugger/flutter/controls.dart';
import 'package:devtools_app/src/debugger/flutter/debugger_controller.dart';
import 'package:devtools_app/src/debugger/flutter/debugger_model.dart';
import 'package:devtools_app/src/debugger/flutter/debugger_screen.dart';
import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../support/mocks.dart';
import '../support/utils.dart';
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
      when(debuggerController.variables).thenReturn(ValueNotifier([]));
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

    testWidgets('has Console / stdio area', (WidgetTester tester) async {
      when(debuggerController.stdio).thenReturn(ValueNotifier(['test stdio']));

      await pumpDebuggerScreen(tester, debuggerController);

      // test for stdio output.
      expect(find.richText('test stdio'), findsOneWidget);
    });

    testWidgets('Console area shows processed ansi text',
        (WidgetTester tester) async {
      when(debuggerController.stdio)
          .thenReturn(ValueNotifier([_ansiCodesOutput()]));

      await pumpDebuggerScreen(tester, debuggerController);

      final finder = find.richText('Ansi color codes processed for console');
      expect(finder, findsOneWidget);
      finder.evaluate().forEach((element) {
        final richText = element.widget as RichText;
        final textSpan = richText.text as TextSpan;
        final secondSpan = textSpan.children[1] as TextSpan;
        expect(
          secondSpan.text,
          'console',
          reason: 'Text with ansi code should be in separate span',
        );
        expect(
          secondSpan.style.backgroundColor,
          const Color.fromRGBO(215, 95, 135, 1),
        );
      });
    });

    group('ConsoleControls', () {
      testWidgets('Console Controls are not rendered when stdio is empty',
          (WidgetTester tester) async {
        when(debuggerController.stdio).thenReturn(ValueNotifier([]));

        await pumpDebuggerScreen(tester, debuggerController);

        expect(find.byKey(DebuggerConsole.clearStdioButtonKey), findsNothing);
        expect(
            find.byKey(DebuggerConsole.copyToClipboardButtonKey), findsNothing);
      });

      testWidgets('Tapping the Console Clear button clears stdio.',
          (WidgetTester tester) async {
        when(debuggerController.stdio)
            .thenReturn(ValueNotifier([_ansiCodesOutput()]));

        await pumpDebuggerScreen(tester, debuggerController);

        final clearButton = find.byKey(DebuggerConsole.clearStdioButtonKey);
        expect(clearButton, findsOneWidget);

        await tester.tap(clearButton);

        verify(debuggerController.clearStdio());
      });

      group('Clipboard', () {
        var _clipboardContents = '';
        final _stdio = ['First line', _ansiCodesOutput(), 'Third line'];
        final _expected = _stdio.join('\n');

        setUp(() {
          // This intercepts the Clipboard.setData SystemChannel message,
          // and stores the contents that were (attempted) to be copied.
          SystemChannels.platform.setMockMethodCallHandler((MethodCall call) {
            switch (call.method) {
              case 'Clipboard.setData':
                _clipboardContents = call.arguments['text'];
                break;
              default:
                break;
            }
            return Future.value(true);
          });
        });

        tearDown(() {
          // Cleanup the SystemChannel
          SystemChannels.platform.setMockMethodCallHandler(null);
        });

        testWidgets(
            'Tapping the Copy to Clipboard button attempts to copy stdio to clipboard.',
            (WidgetTester tester) async {
          when(debuggerController.stdio).thenReturn(ValueNotifier(_stdio));

          await pumpDebuggerScreen(tester, debuggerController);

          final copyButton =
              find.byKey(DebuggerConsole.copyToClipboardButtonKey);
          expect(copyButton, findsOneWidget);

          expect(_clipboardContents, isEmpty);

          await tester.tap(copyButton);

          expect(_clipboardContents, equals(_expected));
        });
      });
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
        'Call Stack shows items', const Size(1000.0, 4000.0),
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

    testWidgetsWithWindowSize(
        'Variables shows items', const Size(1000.0, 4000.0),
        (WidgetTester tester) async {
      when(debuggerController.variables)
          .thenReturn(ValueNotifier(testVariables));
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Variables'), findsOneWidget);

      final listFinder = find.byWidgetPredicate((Widget widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('Root 1 [2] _GrowableList'));
      final listChild1Finder = find.byWidgetPredicate((Widget widget) =>
          widget is RichText && widget.text.toPlainText().contains('0: 3'));
      final listChild2Finder = find.byWidgetPredicate((Widget widget) =>
          widget is RichText && widget.text.toPlainText().contains('1: 4'));

      final mapFinder = find.byWidgetPredicate((Widget widget) =>
          widget is RichText &&
          widget.text
              .toPlainText()
              .contains('Root 2 { 2 } _InternalLinkedHashmap'));
      final mapElement1Finder = find.byWidgetPredicate((Widget widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains("['key1'] 1.0"));
      final mapElement2Finder = find.byWidgetPredicate((Widget widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains("['key2'] 1.1"));

      expect(listFinder, findsOneWidget);
      expect(mapFinder, findsOneWidget);
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains("Root 3 'test str...'")),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Root 4 true')),
        findsOneWidget,
      );

      // Expand list.
      expect(listChild1Finder, findsNothing);
      expect(listChild2Finder, findsNothing);
      await tester.tap(listFinder);
      await tester.pumpAndSettle();
      expect(listChild1Finder, findsOneWidget);
      expect(listChild2Finder, findsOneWidget);

      // Expand map.
      expect(mapElement1Finder, findsNothing);
      expect(mapElement2Finder, findsNothing);
      await tester.tap(mapFinder);
      await tester.pumpAndSettle();
      expect(mapElement1Finder, findsOneWidget);
      expect(mapElement2Finder, findsOneWidget);
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

String _ansiCodesOutput() {
  final sb = StringBuffer();
  sb.write('Ansi color codes processed for ');
  final pen = AnsiPen()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
  sb.write(pen('console'));
  return sb.toString();
}

final testVariables = [
  Variable.create(BoundVariable(
    name: 'Root 1',
    value: InstanceRef(
      kind: InstanceKind.kList,
      classRef: ClassRef(name: '_GrowableList'),
      length: 2,
    ),
    declarationTokenPos: null,
    scopeEndTokenPos: null,
    scopeStartTokenPos: null,
  ))
    ..addAllChildren([
      Variable.create(BoundVariable(
        name: '0:',
        value: InstanceRef(
          kind: InstanceKind.kInt,
          classRef: ClassRef(name: 'Integer'),
          valueAsString: '3',
          valueAsStringIsTruncated: false,
        ),
        declarationTokenPos: null,
        scopeEndTokenPos: null,
        scopeStartTokenPos: null,
      )),
      Variable.create(BoundVariable(
        name: '1:',
        value: InstanceRef(
          kind: InstanceKind.kInt,
          classRef: ClassRef(name: 'Integer'),
          valueAsString: '4',
          valueAsStringIsTruncated: false,
        ),
        declarationTokenPos: null,
        scopeEndTokenPos: null,
        scopeStartTokenPos: null,
      )),
    ]),
  Variable.create(BoundVariable(
    name: 'Root 2',
    value: InstanceRef(
      kind: InstanceKind.kMap,
      classRef: ClassRef(name: '_InternalLinkedHashmap'),
      length: 2,
    ),
    declarationTokenPos: null,
    scopeEndTokenPos: null,
    scopeStartTokenPos: null,
  ))
    ..addAllChildren([
      Variable.create(BoundVariable(
        name: "['key1']",
        value: InstanceRef(
          kind: InstanceKind.kDouble,
          classRef: ClassRef(name: 'Double'),
          valueAsString: '1.0',
          valueAsStringIsTruncated: false,
        ),
        declarationTokenPos: null,
        scopeEndTokenPos: null,
        scopeStartTokenPos: null,
      )),
      Variable.create(BoundVariable(
        name: "['key2']",
        value: InstanceRef(
          kind: InstanceKind.kDouble,
          classRef: ClassRef(name: 'Double'),
          valueAsString: '1.1',
          valueAsStringIsTruncated: false,
        ),
        declarationTokenPos: null,
        scopeEndTokenPos: null,
        scopeStartTokenPos: null,
      )),
    ]),
  Variable.create(BoundVariable(
    name: 'Root 3',
    value: InstanceRef(
      kind: InstanceKind.kString,
      classRef: ClassRef(name: 'String'),
      valueAsString: 'test str',
      valueAsStringIsTruncated: true,
    ),
    declarationTokenPos: null,
    scopeEndTokenPos: null,
    scopeStartTokenPos: null,
  )),
  Variable.create(BoundVariable(
    name: 'Root 4',
    value: InstanceRef(
      kind: InstanceKind.kBool,
      classRef: ClassRef(name: 'Boolean'),
      valueAsString: 'true',
      valueAsStringIsTruncated: false,
    ),
    declarationTokenPos: null,
    scopeEndTokenPos: null,
    scopeStartTokenPos: null,
  )),
];
