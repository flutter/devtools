// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/debugger/codeview_controller.dart';
import 'package:devtools_app/src/screens/debugger/console.dart';
import 'package:devtools_app/src/screens/debugger/controls.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/routing.dart';
import 'package:devtools_app/src/shared/scripts/script_manager.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/debugger/vm_service_object_tree.dart';
import '../test_infra/utils/tree_utils.dart';

Future<void> main() async {
  final screen = DebuggerScreen();

  const windowSize = Size(4000.0, 4000.0);
  const smallWindowSize = Size(1100.0, 1100.0);

  late MockDebuggerController debuggerController;
  late TestProgramExplorerController programExplorerController;
  late VMServiceObjectNode libraryNode;

  setUp(() async {
    final fakeServiceManager = FakeServiceManager();
    final scriptManager = MockScriptManager();
    // ignore: discarded_futures
    when(scriptManager.getScript(any)).thenAnswer(
      (_) => Future<Script>.value(testScript),
    );
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
    fakeServiceManager.consoleService.ensureServiceInitialized();
    when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));

    programExplorerController = TestProgramExplorerController(
      initializer: (controller) {
        libraryNode = VMServiceObjectNode(controller, 'fooLib', testLib);
        libraryNode.script = testScript;
        libraryNode.location = ScriptLocation(testScript);
        controller.rootObjectNodesInternal.add(libraryNode);
      },
    );
    programExplorerController.initialize();
    await programExplorerController.selectNode(libraryNode);

    final codeViewController = createMockCodeViewControllerWithDefaults(
      programExplorerController: programExplorerController,
    );
    when(codeViewController.showFileOpener).thenReturn(ValueNotifier(false));
    when(codeViewController.fileExplorerVisible)
        .thenReturn(ValueNotifier(true));
    debuggerController = createMockDebuggerControllerWithDefaults(
      mockCodeViewController: codeViewController,
    );
  });

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

  testWidgetsWithWindowSize(
    'has Console / stdio area',
    windowSize,
    (WidgetTester tester) async {
      serviceManager.consoleService.appendStdio('test stdio');

      await pumpConsole(tester, debuggerController);

      expect(find.text('Console'), findsOneWidget);

      // test for stdio output.
      expect(find.selectableText('test stdio'), findsOneWidget);
    },
  );

  WidgetPredicate createDebuggerButtonPredicate(String title) {
    return (Widget widget) {
      if (widget is DebuggerButton && widget.title == title) {
        return true;
      }
      return false;
    };
  }

  testWidgetsWithWindowSize(
    'debugger controls running',
    windowSize,
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
    },
  );

  testWidgetsWithWindowSize(
    'debugger controls break on exceptions',
    windowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.build),
          debugger: debuggerController,
        ),
      );
      expect(find.text("Don't stop on exceptions"), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'debugger controls break on exceptions abbreviated on small window',
    smallWindowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.build),
          debugger: debuggerController,
        ),
      );
      expect(find.text('Ignore exceptions'), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'node selection state',
    windowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.build),
          debugger: debuggerController,
        ),
      );
      final delegate = tester
          .firstWidget<MaterialApp>(find.byType(MaterialApp))
          .routerDelegate as DevToolsRouterDelegate;
      final libNode = programExplorerController.rootObjectNodes.value.first;
      final libScript = libraryNode.script!;
      final libScriptRef = ScriptRef(
        id: libScript.id!,
        uri: libScript.uri,
      );

      // Select the library node and ensure the outline is populated.
      final libNodeFinder = find.text(libNode.name);
      expect(libNodeFinder, findsOneWidget);
      await tester.tap(libNodeFinder);
      await tester.pump();

      expect(programExplorerController.scriptSelection, libNode);
      expect(
        programExplorerController.outlineNodes.value
            .where((e) => e.isSelectable),
        isEmpty,
      );
      CodeViewSourceLocationNavigationState? state =
          CodeViewSourceLocationNavigationState.fromState(
        delegate.currentConfiguration!.state,
      );

      expect(state, isNotNull);
      expect(state!.script, libScriptRef);
      expect(state.line, -1);

      // There should be three children total, one root with two children.
      expect(programExplorerController.outlineNodes.value.length, 1);
      expect(programExplorerController.outlineNodes.value.numNodes, 3);

      // Select one of them and check that the outline selection has been
      // updated.
      final outlineNode = programExplorerController.outlineNodes.value.first;
      final outlineNodeFinder = find.text(outlineNode.name);
      expect(outlineNodeFinder, findsOneWidget);
      await tester.tap(outlineNodeFinder);
      await tester.pump();

      expect(programExplorerController.scriptSelection, libNode);
      expect(
        programExplorerController.outlineNodes.value
            .singleWhereOrNull((e) => e.isSelected),
        outlineNode,
      );
      state = CodeViewSourceLocationNavigationState.fromState(
        delegate.currentConfiguration!.state,
      );
      expect(state, isNotNull);
      expect(state!.script, libScriptRef);
      expect(state.line, testClassRef.location!.line);
    },
  );
}

Widget _getWidgetFromFinder(Finder finder) {
  return finder.first.evaluate().first.widget;
}
