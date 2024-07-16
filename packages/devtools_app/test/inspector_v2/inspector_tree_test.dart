// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart'
    hide
        InspectorController,
        InspectorTreeController,
        InspectorTree,
        InspectorTreeConfig,
        InspectorTreeNode;
import 'package:devtools_app/src/screens/inspector_v2/inspector_controller.dart';
import 'package:devtools_app/src/screens/inspector_v2/inspector_tree_controller.dart';
import 'package:devtools_app/src/shared/console/eval/inspector_tree_v2.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

import 'utils/inspector_tree.dart';

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;
  late InspectorController inspectorController;

  setUp(() {
    fakeServiceConnection = FakeServiceConnectionManager();
    final app = fakeServiceConnection.serviceManager.connectedApp!;
    when(app.isFlutterAppNow).thenReturn(true);
    when(app.isProfileBuildNow).thenReturn(false);

    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BreakpointManager, BreakpointManager());
    mockConnectedApp(
      fakeServiceConnection.serviceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );

    inspectorController = InspectorController(
      inspectorTree: InspectorTreeController(),
      treeType: FlutterTreeType.widget,
    )..firstInspectorTreeLoadCompleted = true;
  });

  Future<void> pumpInspectorTree(
    WidgetTester tester, {
    required InspectorTreeController treeController,
  }) async {
    final debuggerController = DebuggerController();
    await tester.pumpWidget(
      wrapWithControllers(
        inspectorV2: inspectorController,
        debugger: debuggerController,
        InspectorTree(
          treeController: treeController,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('InspectorTreeController', () {
    testWidgets(
      'Row with negative index regression test',
      (WidgetTester tester) async {
        final treeController = InspectorTreeController()
          ..config = InspectorTreeConfig(
            onNodeAdded: (_, __) {},
            onClientActiveChange: (_) {},
          );
        await pumpInspectorTree(tester, treeController: treeController);

        expect(treeController.rowForOffset(const Offset(0, -100.0)), isNull);
        expect(treeController.rowOffset(-1), equals(0));

        expect(treeController.rowForOffset(const Offset(0, 0.0)), isNull);
        expect(treeController.rowOffset(0), equals(0));

        treeController.root = InspectorTreeNode()
          ..appendChild(InspectorTreeNode());

        await pumpInspectorTree(tester, treeController: treeController);

        expect(treeController.rowForOffset(const Offset(0, -20))!.index, 0);
        expect(treeController.rowOffset(-1), equals(0));
        expect(treeController.rowForOffset(const Offset(0, 0.0)), isNotNull);
        expect(treeController.rowOffset(0), equals(0));

        // This operation would previously throw an exception in debug builds
        // and infinite loop in release builds.
        treeController.scrollToRect(const Rect.fromLTWH(0, -20, 100, 100));
      },
    );
  });

  group('Inspector tree content preview', () {
    testWidgets('Shows simple text preview', (WidgetTester tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Content'),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);
      await pumpInspectorTree(tester, treeController: treeController);

      expect(find.richText('Text: "Content"'), findsOneWidget);
    });

    testWidgets('Shows preview from Text.rich', (WidgetTester tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Rich '),
              TextSpan(text: 'text'),
            ],
          ),
        ),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);
      await pumpInspectorTree(tester, treeController: treeController);

      expect(find.richText('Text: "Rich text"'), findsOneWidget);
    });

    testWidgets(
      'Strips new lines from text preview',
      (WidgetTester tester) async {
        final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
          widget: const Text('Multiline\ntext\n\ncontent'),
          tester: tester,
        );

        final treeController = inspectorTreeControllerFromNode(diagnosticNode);
        await pumpInspectorTree(tester, treeController: treeController);

        expect(
          find.richText('Text: "Multiline text  content"'),
          findsOneWidget,
        );
      },
    );
  });
}
