// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/inspector/inspector_breadcrumbs.dart';
import 'package:devtools_app/src/screens/inspector/inspector_controller.dart';
import 'package:devtools_app/src/screens/inspector/inspector_tree.dart';
import 'package:devtools_app/src/screens/inspector/inspector_tree_controller.dart';
import 'package:devtools_app/src/screens/inspector/primitives/inspector_common.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

import 'utils/inspector_tree.dart';

void main() {
  late FakeServiceManager fakeServiceManager;
  late InspectorController inspectorController;

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    final app = fakeServiceManager.connectedApp!;
    when(app.isFlutterAppNow).thenReturn(true);
    when(app.isProfileBuildNow).thenReturn(false);

    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BreakpointManager, BreakpointManager());
    mockConnectedApp(
      fakeServiceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );

    inspectorController = InspectorController(
      inspectorTree: InspectorTreeController(),
      detailsTree: InspectorTreeController(),
      treeType: FlutterTreeType.widget,
    )..firstInspectorTreeLoadCompleted = true;
  });

  Future<void> pumpInspectorTree(
    WidgetTester tester, {
    required InspectorTreeController treeController,
    bool isSummaryTree = false,
  }) async {
    final debuggerController = DebuggerController();
    final summaryTreeController =
        isSummaryTree ? null : InspectorTreeController();
    await tester.pumpWidget(
      wrapWithControllers(
        inspector: inspectorController,
        debugger: debuggerController,
        InspectorTree(
          treeController: treeController,
          summaryTreeController: summaryTreeController,
          isSummaryTree: isSummaryTree,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('InspectorTreeController', () {
    testWidgets('Row with negative index regression test',
        (WidgetTester tester) async {
      final treeController = InspectorTreeController()
        ..config = InspectorTreeConfig(
          summaryTree: false,
          treeType: FlutterTreeType.widget,
          onNodeAdded: (_, __) {},
          onClientActiveChange: (_) {},
        );
      await pumpInspectorTree(tester, treeController: treeController);

      expect(treeController.getRow(const Offset(0, -100.0)), isNull);
      expect(treeController.getRowOffset(-1), equals(0));

      expect(treeController.getRow(const Offset(0, 0.0)), isNull);
      expect(treeController.getRowOffset(0), equals(0));

      treeController.root = InspectorTreeNode()
        ..appendChild(InspectorTreeNode());

      await pumpInspectorTree(tester, treeController: treeController);

      expect(treeController.getRow(const Offset(0, -20))!.index, 0);
      expect(treeController.getRowOffset(-1), equals(0));
      expect(treeController.getRow(const Offset(0, 0.0)), isNotNull);
      expect(treeController.getRowOffset(0), equals(0));

      // This operation would previously throw an exception in debug builds
      // and infinite loop in release builds.
      treeController.scrollToRect(const Rect.fromLTWH(0, -20, 100, 100));
    });
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

    testWidgets('Strips new lines from text preview',
        (WidgetTester tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Multiline\ntext\n\ncontent'),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);
      await pumpInspectorTree(tester, treeController: treeController);

      expect(find.richText('Text: "Multiline text  content"'), findsOneWidget);
    });

    testWidgets('Shows breadcrumbs in Widget detail tree', (tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Hello'),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);
      await pumpInspectorTree(tester, treeController: treeController);

      expect(find.byType(InspectorBreadcrumbNavigator), findsOneWidget);
    });

    testWidgets('Shows no breadcrumbs widget in summary tree', (tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Hello'),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);
      await pumpInspectorTree(
        tester,
        treeController: treeController,
        isSummaryTree: true,
      );

      expect(find.byType(InspectorBreadcrumbNavigator), findsNothing);
    });
  });
}
