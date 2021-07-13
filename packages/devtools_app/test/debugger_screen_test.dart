// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/src/debugger/console.dart';
import 'package:devtools_app/src/debugger/controls.dart';
import 'package:devtools_app/src/debugger/debugger_controller.dart';
import 'package:devtools_app/src/debugger/debugger_model.dart';
import 'package:devtools_app/src/debugger/debugger_screen.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';
import 'support/utils.dart';
import 'support/wrappers.dart';

void main() {
  DebuggerScreen screen;
  FakeServiceManager fakeServiceManager;
  MockDebuggerController debuggerController;
  fakeServiceManager = FakeServiceManager();
  when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceManager);

  const windowSize = Size(4000.0, 4000.0);

  group('DebuggerScreen', () {
    Future<void> pumpDebuggerScreen(
        WidgetTester tester, DebuggerController controller) async {
      await tester.pumpWidget(wrapWithControllers(
        const DebuggerScreenBody(),
        debugger: controller,
      ));
    }

    Future<void> pumpConsole(
        WidgetTester tester, DebuggerController controller) async {
      await tester.pumpWidget(wrapWithControllers(
        const DebuggerConsole(),
        debugger: controller,
      ));
    }

    setUp(() {
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
          .thenReturn(ValueNotifier<int>(0));

      screen = const DebuggerScreen();

      debuggerController = MockDebuggerController.withDefaults();
    });

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

    testWidgetsWithWindowSize(
        'Console area shows processed ansi text', windowSize,
        (WidgetTester tester) async {
      serviceManager.consoleService.appendStdio(_ansiCodesOutput());

      await pumpConsole(tester, debuggerController);

      final finder =
          find.selectableText('Ansi color codes processed for console');
      expect(finder, findsOneWidget);
      finder.evaluate().forEach((element) {
        final selectableText = element.widget as SelectableText;
        final textSpan = selectableText.textSpan;
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
      testWidgetsWithWindowSize(
          'Tapping the Console Clear button clears stdio.', windowSize,
          (WidgetTester tester) async {
        serviceManager.consoleService.clearStdio();
        serviceManager.consoleService.appendStdio(_ansiCodesOutput());

        await pumpConsole(tester, debuggerController);

        final clearButton = find.byKey(DebuggerConsole.clearStdioButtonKey);
        expect(clearButton, findsOneWidget);

        await tester.tap(clearButton);

        expect(serviceManager.consoleService.stdio.value, isEmpty);
      });

      final _stdio = ['First line', _ansiCodesOutput(), 'Third line'];

      void _appendStdioLines() {
        for (var line in _stdio) {
          serviceManager.consoleService.appendStdio('$line\n');
        }
      }

      group('Clipboard', () {
        _appendStdioLines();
        var _clipboardContents = '';
        final _expected = _stdio.join('\n');

        setUp(() {
          // This intercepts the Clipboard.setData SystemChannel message,
          // and stores the contents that were (attempted) to be copied.
          SystemChannels.platform.setMockMethodCallHandler((MethodCall call) {
            switch (call.method) {
              case 'Clipboard.setData':
                _clipboardContents = call.arguments['text'];
                return Future.value(true);
                break;
              case 'Clipboard.getData':
                return Future.value(<String, dynamic>{});
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

        testWidgetsWithWindowSize(
            'Tapping the Copy to Clipboard button attempts to copy stdio to clipboard.',
            windowSize, (WidgetTester tester) async {
          _appendStdioLines();

          await pumpConsole(tester, debuggerController);

          final copyButton =
              find.byKey(DebuggerConsole.copyToClipboardButtonKey);
          expect(copyButton, findsOneWidget);

          expect(_clipboardContents, isEmpty);

          await tester.tap(copyButton);

          expect(_clipboardContents, equals(_expected));
        });
      });
    });

    testWidgetsWithWindowSize('Libraries hidden', windowSize,
        (WidgetTester tester) async {
      final scripts = [
        ScriptRef(uri: 'package:/test/script.dart', id: 'test-script')
      ];

      when(debuggerController.sortedScripts).thenReturn(ValueNotifier(scripts));

      // Libraries view is hidden
      when(debuggerController.librariesVisible)
          .thenReturn(ValueNotifier(false));
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Libraries'), findsOneWidget);
    });

    testWidgetsWithWindowSize('Libraries visible', windowSize,
        (WidgetTester tester) async {
      final scripts = [
        ScriptRef(uri: 'package:test/script.dart', id: 'test-script')
      ];

      when(debuggerController.sortedScripts).thenReturn(ValueNotifier(scripts));

      // Libraries view is shown
      when(debuggerController.librariesVisible).thenReturn(ValueNotifier(true));
      await pumpDebuggerScreen(tester, debuggerController);
      // One for the button and one for the title of the Libraries view.
      expect(find.text('Libraries'), findsNWidgets(2));

      // test for items in the libraries tree
      expect(find.text(scripts.first.uri.split('/').first), findsOneWidget);
    });

    testWidgetsWithWindowSize('Breakpoints show items', windowSize,
        (WidgetTester tester) async {
      final breakpoints = [
        Breakpoint(
          breakpointNumber: 1,
          id: 'bp1',
          resolved: false,
          location: UnresolvedSourceLocation(
            scriptUri: 'package:test/script.dart',
            line: 10,
          ),
          enabled: true,
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

    testWidgetsWithWindowSize('Call Stack shows items', windowSize,
        (WidgetTester tester) async {
      final stackFrames = [
        Frame(
          index: 0,
          code: CodeRef(
              name: 'testCodeRef', id: 'testCodeRef', kind: CodeKind.kDart),
          location: SourceLocation(
            script:
                ScriptRef(uri: 'package:test/script.dart', id: 'script.dart'),
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
      await pumpDebuggerScreen(tester, debuggerController);

      expect(find.text('Call Stack'), findsOneWidget);

      // Stack frame 0
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('testCodeRef() script.dart 0')),
        findsOneWidget,
      );

      // verify that the frame has a tooltip
      expect(
        find.byTooltip('testCodeRef() script.dart 0'),
        findsOneWidget,
      );

      // Stack frame 1
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('<none> script1.dart 1')),
        findsOneWidget,
      );
      // Stack frame 2
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text
                .toPlainText()
                .contains('testCodeRef2() script2.dart 2')),
        findsOneWidget,
      );
      // Stack frame 3
      expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is RichText &&
            widget.text
                .toPlainText()
                .contains('testCodeRef3.<closure>() script3.dart 3')),
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

      final listFinder = find.selectableText('Root 1: _GrowableList (2 items)');

      // expect a tooltip for the list value
      expect(
        find.byTooltip('_GrowableList (2 items)'),
        findsOneWidget,
      );

      final mapFinder = find
          .selectableTextContaining('Root 2: _InternalLinkedHashmap (2 items)');
      final mapElement1Finder = find.selectableTextContaining("['key1']: 1.0");
      final mapElement2Finder = find.selectableTextContaining("['key2']: 1.1");

      expect(listFinder, findsOneWidget);
      expect(mapFinder, findsOneWidget);
      expect(
        find.selectableTextContaining("Root 3: 'test str...'"),
        findsOneWidget,
      );
      expect(
        find.selectableTextContaining('Root 4: true'),
        findsOneWidget,
      );

      // Expand list.
      expect(find.selectableTextContaining('0: 3'), findsNothing);
      expect(find.selectableTextContaining('1: 4'), findsNothing);
      await tester.tap(listFinder);
      await tester.pumpAndSettle();
      expect(find.selectableTextContaining('0: 3'), findsOneWidget);
      expect(find.selectableTextContaining('1: 4'), findsOneWidget);

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

    testWidgetsWithWindowSize('debugger controls running', windowSize,
        (WidgetTester tester) async {
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

    testWidgetsWithWindowSize('debugger controls paused', windowSize,
        (WidgetTester tester) async {
      when(debuggerController.isPaused).thenReturn(ValueNotifier(true));
      when(debuggerController.stackFramesWithLocation)
          .thenReturn(ValueNotifier([
        StackFrameAndSourcePosition(
          Frame(
            index: 0,
            code: CodeRef(
                name: 'testCodeRef', id: 'testCodeRef', kind: CodeKind.kDart),
            location: SourceLocation(
              script:
                  ScriptRef(uri: 'package:test/script.dart', id: 'script.dart'),
              tokenPos: 10,
            ),
            kind: FrameKind.kRegular,
          ),
          position: SourcePosition(
            line: 1,
            column: 10,
          ),
        )
      ]));

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

    testWidgetsWithWindowSize(
        'debugger controls break on exceptions', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ));
      expect(find.text('Ignore'), findsOneWidget);
    });
  });

  group('FloatingDebuggerControls', () {
    setUp(() {
      debuggerController = MockDebuggerController();
      when(debuggerController.isPaused).thenReturn(ValueNotifier<bool>(true));
    });

    Future<void> pumpControls(WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        FloatingDebuggerControls(),
        debugger: debuggerController,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('display as expected', (WidgetTester tester) async {
      await pumpControls(tester);
      final animatedOpacityFinder = find.byType(AnimatedOpacity);
      expect(animatedOpacityFinder, findsOneWidget);
      final AnimatedOpacity animatedOpacity =
          animatedOpacityFinder.evaluate().first.widget;
      expect(animatedOpacity.opacity, equals(1.0));
      expect(
          find.text('Main isolate is paused in the debugger'), findsOneWidget);
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Step over'), findsOneWidget);
    });

    testWidgets('can resume', (WidgetTester tester) async {
      bool didResume = false;
      Future<Success> resume() {
        didResume = true;
        return Future.value(Success());
      }

      when(debuggerController.resume()).thenAnswer((_) => resume());
      await pumpControls(tester);
      expect(didResume, isFalse);
      await tester.tap(find.byTooltip('Resume'));
      await tester.pumpAndSettle();
      expect(didResume, isTrue);
    });

    testWidgets('can step over', (WidgetTester tester) async {
      bool didStep = false;
      Future<Success> stepOver() {
        didStep = true;
        return Future.value(Success());
      }

      when(debuggerController.stepOver()).thenAnswer((_) => stepOver());
      await pumpControls(tester);
      expect(didStep, isFalse);
      await tester.tap(find.byTooltip('Step over'));
      await tester.pumpAndSettle();
      expect(didStep, isTrue);
    });

    testWidgets('are hidden when app is not paused',
        (WidgetTester tester) async {
      when(debuggerController.isPaused).thenReturn(ValueNotifier<bool>(false));
      await pumpControls(tester);
      final animatedOpacityFinder = find.byType(AnimatedOpacity);
      expect(animatedOpacityFinder, findsOneWidget);
      final AnimatedOpacity animatedOpacity =
          animatedOpacityFinder.evaluate().first.widget;
      expect(animatedOpacity.opacity, equals(0.0));
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

final libraryRef = LibraryRef(
  name: 'some library',
  uri: 'package:foo/foo.dart',
  id: 'lib-id-1',
);

final isolateRef = IsolateRef(
  id: '433',
  number: '1',
  name: 'my-isolate',
  isSystemIsolate: false,
);

final testVariables = [
  Variable.create(
    BoundVariable(
      name: 'Root 1',
      value: InstanceRef(
        id: 'ref1',
        kind: InstanceKind.kList,
        classRef: ClassRef(
          name: '_GrowableList',
          id: 'ref2',
          library: libraryRef,
        ),
        length: 2,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  )..addAllChildren([
      Variable.create(
        BoundVariable(
          name: '0',
          value: InstanceRef(
            id: 'ref3',
            kind: InstanceKind.kInt,
            classRef:
                ClassRef(name: 'Integer', id: 'ref4', library: libraryRef),
            valueAsString: '3',
            valueAsStringIsTruncated: false,
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        isolateRef,
      ),
      Variable.create(
        BoundVariable(
          name: '1',
          value: InstanceRef(
            id: 'ref5',
            kind: InstanceKind.kInt,
            classRef:
                ClassRef(name: 'Integer', id: 'ref6', library: libraryRef),
            valueAsString: '4',
            valueAsStringIsTruncated: false,
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        isolateRef,
      ),
    ]),
  Variable.create(
    BoundVariable(
      name: 'Root 2',
      value: InstanceRef(
        id: 'ref7',
        kind: InstanceKind.kMap,
        classRef: ClassRef(
            name: '_InternalLinkedHashmap', id: 'ref8', library: libraryRef),
        length: 2,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  )..addAllChildren([
      Variable.create(
        BoundVariable(
          name: "['key1']",
          value: InstanceRef(
            id: 'ref9',
            kind: InstanceKind.kDouble,
            classRef:
                ClassRef(name: 'Double', id: 'ref10', library: libraryRef),
            valueAsString: '1.0',
            valueAsStringIsTruncated: false,
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        isolateRef,
      ),
      Variable.create(
        BoundVariable(
          name: "['key2']",
          value: InstanceRef(
            id: 'ref11',
            kind: InstanceKind.kDouble,
            classRef:
                ClassRef(name: 'Double', id: 'ref12', library: libraryRef),
            valueAsString: '1.1',
            valueAsStringIsTruncated: false,
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        isolateRef,
      ),
    ]),
  Variable.create(
    BoundVariable(
      name: 'Root 3',
      value: InstanceRef(
        id: 'ref13',
        kind: InstanceKind.kString,
        classRef: ClassRef(name: 'String', id: 'ref14', library: libraryRef),
        valueAsString: 'test str',
        valueAsStringIsTruncated: true,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  ),
  Variable.create(
    BoundVariable(
      name: 'Root 4',
      value: InstanceRef(
        id: 'ref15',
        kind: InstanceKind.kBool,
        classRef: ClassRef(name: 'Boolean', id: 'ref16', library: libraryRef),
        valueAsString: 'true',
        valueAsStringIsTruncated: false,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  ),
];
