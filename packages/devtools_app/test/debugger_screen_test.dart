// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/console.dart';
import 'package:devtools_app/src/screens/debugger/controls.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer_model.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  DebuggerScreen screen;
  FakeServiceManager fakeServiceManager;
  MockDebuggerController debuggerController;
  MockScriptManager scriptManager;

  const windowSize = Size(4000.0, 4000.0);
  const smallWindowSize = Size(1000.0, 1000.0);

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    scriptManager = MockScriptManager();
    when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, scriptManager);
    fakeServiceManager.consoleService.ensureServiceInitialized();
  });

  group('DebuggerScreen', () {
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

    group('ConsoleControls', () {
      final _stdio = ['First line', _ansiCodesOutput(), 'Third line'];

      void _appendStdioLines() {
        for (var line in _stdio) {
          serviceManager.consoleService.appendStdio('$line\n');
        }
      }

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

      group('Clipboard', () {
        var _clipboardContents = '';
        final _expected = _stdio.join('\n');

        setUp(() {
          _appendStdioLines();
          // This intercepts the Clipboard.setData SystemChannel message,
          // and stores the contents that were (attempted) to be copied.
          SystemChannels.platform.setMockMethodCallHandler((MethodCall call) {
            switch (call.method) {
              case 'Clipboard.setData':
                _clipboardContents = call.arguments['text'];
                break;
              case 'Clipboard.getData':
                return Future.value(<String, dynamic>{});
                break;
              case 'Clipboard.hasStrings':
                return Future.value(<String, dynamic>{'value': true});
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

    group('Codeview', () {
      setUp(() {
        final scriptsHistory = ScriptsHistory();
        scriptsHistory.pushEntry(mockScript);
        when(debuggerController.currentScriptRef)
            .thenReturn(ValueNotifier(mockScriptRef));
        when(debuggerController.currentParsedScript)
            .thenReturn(ValueNotifier(mockParsedScript));
        when(debuggerController.showSearchInFileField)
            .thenReturn(ValueNotifier(false));
        when(debuggerController.showFileOpener)
            .thenReturn(ValueNotifier(false));
        when(debuggerController.scriptsHistory).thenReturn(scriptsHistory);
        when(debuggerController.searchMatches).thenReturn(ValueNotifier([]));
        when(debuggerController.activeSearchMatch)
            .thenReturn(ValueNotifier(null));
      });

      testWidgetsWithWindowSize(
        'has a horizontal and a vertical scrollbar',
        smallWindowSize,
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
            matchesGoldenFile('goldens/codeview_scrollbars.png'),
          );
        },
        skip: !Platform.isMacOS,
      );
    });

    testWidgetsWithWindowSize('File Explorer hidden', windowSize,
        (WidgetTester tester) async {
      final scripts = [
        ScriptRef(uri: 'package:/test/script.dart', id: 'test-script')
      ];

      when(debuggerController.programExplorerController.selectedNodeIndex)
          .thenReturn(ValueNotifier(0));
      when(scriptManager.sortedScripts).thenReturn(ValueNotifier(scripts));
      when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));

      // File Explorer view is hidden
      when(debuggerController.fileExplorerVisible)
          .thenReturn(ValueNotifier(false));
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('File Explorer'), findsOneWidget);
    });

    testWidgetsWithWindowSize('File Explorer visible', windowSize,
        (WidgetTester tester) async {
      final scripts = [
        ScriptRef(uri: 'package:test/script.dart', id: 'test-script')
      ];

      when(debuggerController.programExplorerController.selectedNodeIndex)
          .thenReturn(ValueNotifier(0));
      when(scriptManager.sortedScripts).thenReturn(ValueNotifier(scripts));
      when(debuggerController.programExplorerController.rootObjectNodes)
          .thenReturn(
        ValueNotifier(
          [
            VMServiceObjectNode(
              debuggerController.programExplorerController,
              'package:test',
              null,
            ),
          ],
        ),
      );
      when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));

      // File Explorer view is shown
      when(debuggerController.fileExplorerVisible)
          .thenReturn(ValueNotifier(true));
      await pumpDebuggerScreen(tester, debuggerController);
      // One for the button and one for the title of the File Explorer view.
      expect(find.text('File Explorer'), findsNWidgets(2));

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
          const SourcePosition(line: 10, column: 1),
        )
      ];

      when(debuggerController.breakpoints)
          .thenReturn(ValueNotifier(breakpoints));
      when(debuggerController.breakpointsWithLocation)
          .thenReturn(ValueNotifier(breakpointsWithLocation));

      when(scriptManager.sortedScripts).thenReturn(ValueNotifier([]));
      when(debuggerController.scriptLocation).thenReturn(ValueNotifier(null));
      when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));

      await pumpDebuggerScreen(tester, debuggerController);

      expect(find.text('Breakpoints'), findsOneWidget);

      // test for items in the breakpoint list
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('script.dart:10'),
        ),
        findsOneWidget,
      );
    });

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

    group('Variables', () {
      setUp(() {
        resetRef();
        resetRoot();
      });

      testWidgetsWithWindowSize(
          'Variables shows items', const Size(1000.0, 4000.0),
          (WidgetTester tester) async {
        when(debuggerController.variables).thenReturn(
          ValueNotifier(
            [
              buildListVariable(),
              buildMapVariable(),
              buildStringVariable('test str'),
              buildBooleanVariable(true),
            ],
          ),
        );
        await pumpDebuggerScreen(tester, debuggerController);
        expect(find.text('Variables'), findsOneWidget);

        final listFinder =
            find.selectableText('Root 1: _GrowableList (2 items)');

        // expect a tooltip for the list value
        expect(
          find.byTooltip('_GrowableList (2 items)'),
          findsOneWidget,
        );

        final mapFinder = find.selectableTextContaining(
          'Root 2: _InternalLinkedHashmap (2 items)',
        );
        final mapElement1Finder =
            find.selectableTextContaining("['key1']: 1.0");
        final mapElement2Finder =
            find.selectableTextContaining("['key2']: 2.0");

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

        // Initially list is not expanded.
        expect(find.selectableTextContaining('0: 3'), findsNothing);
        expect(find.selectableTextContaining('1: 4'), findsNothing);

        // Expand list.
        await tester.tap(listFinder);
        await tester.pump();
        expect(find.selectableTextContaining('0: 0'), findsOneWidget);
        expect(find.selectableTextContaining('1: 1'), findsOneWidget);

        // Initially map is not expanded.
        expect(mapElement1Finder, findsNothing);
        expect(mapElement2Finder, findsNothing);

        // Expand map.
        await tester.tap(mapFinder);
        await tester.pump();
        expect(mapElement1Finder, findsOneWidget);
        expect(mapElement2Finder, findsOneWidget);
      });

      testWidgetsWithWindowSize('Children in large list variables are grouped',
          const Size(1000.0, 4000.0), (WidgetTester tester) async {
        final list = buildParentListVariable(length: 380250);
        await buildVariablesTree(list);
        when(debuggerController.variables).thenReturn(
          ValueNotifier(
            [
              list,
            ],
          ),
        );
        await pumpDebuggerScreen(tester, debuggerController);

        final listFinder =
            find.selectableText('Root 1: _GrowableList (380,250 items)');
        final group0To9999Finder = find.selectableTextContaining('[0 - 9999]');
        final group10000To19999Finder =
            find.selectableTextContaining('[10000 - 19999]');
        final group370000To379999Finder =
            find.selectableTextContaining('[370000 - 379999]');
        final group380000To380249Finder =
            find.selectableTextContaining('[380000 - 380249]');

        final group370000To370099Finder =
            find.selectableTextContaining('[370000 - 370099]');
        final group370100To370199Finder =
            find.selectableTextContaining('[370100 - 370199]');
        final group370200To370299Finder =
            find.selectableTextContaining('[370200 - 370299]');

        // Initially list is not expanded.
        expect(listFinder, findsOneWidget);
        expect(group0To9999Finder, findsNothing);
        expect(group10000To19999Finder, findsNothing);
        expect(group370000To379999Finder, findsNothing);
        expect(group380000To380249Finder, findsNothing);

        // Expand list.
        await tester.tap(listFinder);
        await tester.pump();
        expect(group0To9999Finder, findsOneWidget);
        expect(group10000To19999Finder, findsOneWidget);
        expect(group370000To379999Finder, findsOneWidget);
        expect(group380000To380249Finder, findsOneWidget);

        // Initially group [370000 - 379999] is not expanded.
        expect(group370000To370099Finder, findsNothing);
        expect(group370100To370199Finder, findsNothing);
        expect(group370200To370299Finder, findsNothing);

        // Expand group [370000 - 379999].
        await tester.tap(group370000To379999Finder);
        await tester.pump();
        expect(group370000To370099Finder, findsOneWidget);
        expect(group370100To370199Finder, findsOneWidget);
        expect(group370200To370299Finder, findsOneWidget);
      });

      testWidgetsWithWindowSize('Children in large map variables are grouped',
          const Size(1000.0, 4000.0), (WidgetTester tester) async {
        final map = buildParentMapVariable(length: 243621);
        await buildVariablesTree(map);
        when(debuggerController.variables).thenReturn(
          ValueNotifier(
            [
              map,
            ],
          ),
        );
        await pumpDebuggerScreen(tester, debuggerController);

        final listFinder = find
            .selectableText('Root 1: _InternalLinkedHashmap (243,621 items)');
        final group0To9999Finder = find.selectableTextContaining('[0 - 9999]');
        final group10000To19999Finder =
            find.selectableTextContaining('[10000 - 19999]');
        final group230000To239999Finder =
            find.selectableTextContaining('[230000 - 239999]');
        final group240000To243620Finder =
            find.selectableTextContaining('[240000 - 243620]');

        final group0To99Finder = find.selectableTextContaining('[0 - 99]');
        final group100To199Finder =
            find.selectableTextContaining('[100 - 199]');
        final group200To299Finder =
            find.selectableTextContaining('[200 - 299]');

        // Initially map is not expanded.
        expect(listFinder, findsOneWidget);
        expect(group0To9999Finder, findsNothing);
        expect(group10000To19999Finder, findsNothing);
        expect(group230000To239999Finder, findsNothing);
        expect(group240000To243620Finder, findsNothing);

        // Expand map.
        await tester.tap(listFinder);
        await tester.pump();
        expect(group0To9999Finder, findsOneWidget);
        expect(group10000To19999Finder, findsOneWidget);
        expect(group230000To239999Finder, findsOneWidget);
        expect(group240000To243620Finder, findsOneWidget);

        // Initially group [0 - 9999] is not expanded.
        expect(group0To99Finder, findsNothing);
        expect(group100To199Finder, findsNothing);
        expect(group200To299Finder, findsNothing);

        // Expand group [0 - 9999].
        await tester.tap(group0To9999Finder);
        await tester.pump();
        expect(group0To99Finder, findsOneWidget);
        expect(group100To199Finder, findsOneWidget);
        expect(group200To299Finder, findsOneWidget);
      });
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
      when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));
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
      final DebuggerButton pause = getWidgetFromFinder(
        find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')),
      );
      expect(pause.onPressed, isNotNull);

      expect(
        find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
        findsOneWidget,
      );
      final DebuggerButton resume = getWidgetFromFinder(
        find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
      );
      expect(resume.onPressed, isNull);
    });

    testWidgetsWithWindowSize('debugger controls paused', windowSize,
        (WidgetTester tester) async {
      when(debuggerController.isPaused).thenReturn(ValueNotifier(true));
      when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));
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
      final DebuggerButton pause = getWidgetFromFinder(
        find.byWidgetPredicate(createDebuggerButtonPredicate('Pause')),
      );
      expect(pause.onPressed, isNull);

      expect(
        find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
        findsOneWidget,
      );
      final DebuggerButton resume = getWidgetFromFinder(
        find.byWidgetPredicate(createDebuggerButtonPredicate('Resume')),
      );
      expect(resume.onPressed, isNotNull);
    });

    testWidgetsWithWindowSize(
        'debugger controls break on exceptions', windowSize,
        (WidgetTester tester) async {
      when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.build),
          debugger: debuggerController,
        ),
      );
      expect(find.text('Ignore'), findsOneWidget);
    });
  });

  group('FloatingDebuggerControls', () {
    setUp(() {
      debuggerController = MockDebuggerController();
      when(debuggerController.isPaused).thenReturn(ValueNotifier<bool>(true));
    });

    Future<void> pumpControls(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          FloatingDebuggerControls(),
          debugger: debuggerController,
        ),
      );
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
        find.text('Main isolate is paused in the debugger'),
        findsOneWidget,
      );
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

int refNumber = 0;

String incrementRef() {
  refNumber++;
  return 'ref$refNumber';
}

void resetRef() {
  refNumber = 0;
}

int rootNumber = 0;

String incrementRoot() {
  rootNumber++;
  return 'Root $rootNumber';
}

void resetRoot() {
  rootNumber = 0;
}

DartObjectNode buildParentListVariable({int length = 2}) {
  return DartObjectNode.create(
    BoundVariable(
      name: incrementRoot(),
      value: InstanceRef(
        id: incrementRef(),
        kind: InstanceKind.kList,
        classRef: ClassRef(
          name: '_GrowableList',
          id: incrementRef(),
          library: libraryRef,
        ),
        length: length,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  );
}

DartObjectNode buildListVariable({int length = 2}) {
  final listVariable = buildParentListVariable(length: length);

  for (int i = 0; i < length; i++) {
    listVariable.addChild(
      DartObjectNode.create(
        BoundVariable(
          name: '$i',
          value: InstanceRef(
            id: incrementRef(),
            kind: InstanceKind.kInt,
            classRef: ClassRef(
              name: 'Integer',
              id: incrementRef(),
              library: libraryRef,
            ),
            valueAsString: '$i',
            valueAsStringIsTruncated: false,
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        isolateRef,
      ),
    );
  }

  return listVariable;
}

DartObjectNode buildParentMapVariable({int length = 2}) {
  return DartObjectNode.create(
    BoundVariable(
      name: incrementRoot(),
      value: InstanceRef(
        id: incrementRef(),
        kind: InstanceKind.kMap,
        classRef: ClassRef(
          name: '_InternalLinkedHashmap',
          id: incrementRef(),
          library: libraryRef,
        ),
        length: length,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  );
}

DartObjectNode buildMapVariable({int length = 2}) {
  final mapVariable = buildParentMapVariable(length: length);

  for (int i = 0; i < length; i++) {
    mapVariable.addChild(
      DartObjectNode.create(
        BoundVariable(
          name: "['key${i + 1}']",
          value: InstanceRef(
            id: incrementRef(),
            kind: InstanceKind.kDouble,
            classRef: ClassRef(
              name: 'Double',
              id: incrementRef(),
              library: libraryRef,
            ),
            valueAsString: '${i + 1}.0',
            valueAsStringIsTruncated: false,
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        isolateRef,
      ),
    );
  }

  return mapVariable;
}

DartObjectNode buildStringVariable(String value) {
  return DartObjectNode.create(
    BoundVariable(
      name: incrementRoot(),
      value: InstanceRef(
        id: incrementRef(),
        kind: InstanceKind.kString,
        classRef: ClassRef(
          name: 'String',
          id: incrementRef(),
          library: libraryRef,
        ),
        valueAsString: value,
        valueAsStringIsTruncated: true,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  );
}

DartObjectNode buildBooleanVariable(bool value) {
  return DartObjectNode.create(
    BoundVariable(
      name: incrementRoot(),
      value: InstanceRef(
        id: incrementRef(),
        kind: InstanceKind.kBool,
        classRef: ClassRef(
          name: 'Boolean',
          id: incrementRef(),
          library: libraryRef,
        ),
        valueAsString: '$value',
        valueAsStringIsTruncated: false,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    isolateRef,
  );
}
