// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/inspector/inspector_breadcrumbs.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/inspector/inspector_tree_controller.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_app/src/shared/service_manager.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

import 'test_utils/inspector_tree.dart';

void main() {
  FakeServiceManager fakeServiceManager;

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);

    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    mockIsFlutterApp(serviceManager.connectedApp);
  });

  group('InspectorTreeController', () {
    testWidgets('Row with negative index regression test',
        (WidgetTester tester) async {
      final controller = InspectorTreeController()
        ..config = InspectorTreeConfig(
          summaryTree: false,
          treeType: FlutterTreeType.widget,
          onNodeAdded: (_, __) {},
          onClientActiveChange: (_) {},
        );
      final debuggerController = TestDebuggerController();
      await tester.pumpWidget(wrap(InspectorTree(
        controller: controller,
        debuggerController: debuggerController,
        inspectorTreeController: InspectorTreeController(),
      )));

      expect(controller.getRow(const Offset(0, -100.0)), isNull);
      expect(controller.getRowOffset(-1), equals(0));

      expect(controller.getRow(const Offset(0, 0.0)), isNull);
      expect(controller.getRowOffset(0), equals(0));

      controller.root = InspectorTreeNode()..appendChild(InspectorTreeNode());
      await tester.pumpWidget(wrap(InspectorTree(
        controller: controller,
        debuggerController: debuggerController,
        inspectorTreeController: InspectorTreeController(),
      )));

      expect(controller.getRow(const Offset(0, -20)).index, 0);
      expect(controller.getRowOffset(-1), equals(0));
      expect(controller.getRow(const Offset(0, 0.0)), isNotNull);
      expect(controller.getRowOffset(0), equals(0));

      // This operation would previously throw an exception in debug builds
      // and infinite loop in release builds.
      controller.scrollToRect(const Rect.fromLTWH(0, -20, 100, 100));
    });
  });

  group('Inspector tree content preview', () {
    testWidgets('Shows simple text preview', (WidgetTester tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Content'),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);
      await tester.pumpWidget(wrap(InspectorTree(
        controller: treeController,
        debuggerController: TestDebuggerController(),
        inspectorTreeController: InspectorTreeController(),
      )));

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
      await tester.pumpWidget(wrap(InspectorTree(
        controller: treeController,
        debuggerController: TestDebuggerController(),
        inspectorTreeController: InspectorTreeController(),
      )));

      expect(find.richText('Text: "Rich text"'), findsOneWidget);
    });

    testWidgets('Strips new lines from text preview',
        (WidgetTester tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Multiline\ntext\n\ncontent'),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);

      await tester.pumpWidget(
        wrap(InspectorTree(
          controller: treeController,
          debuggerController: TestDebuggerController(),
          inspectorTreeController: InspectorTreeController(),
        )),
      );

      expect(find.richText('Text: "Multiline text  content"'), findsOneWidget);
    });

    testWidgets('Shows breadcrumbs in Widget detail tree', (tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Hello'),
        tester: tester,
      );

      final controller = inspectorTreeControllerFromNode(diagnosticNode);
      await tester.pumpWidget(wrap(
        InspectorTree(
          controller: controller,
          debuggerController: TestDebuggerController(),
          inspectorTreeController: InspectorTreeController(),
          // ignore: avoid_redundant_argument_values
          isSummaryTree: false,
        ),
      ));

      expect(find.byType(InspectorBreadcrumbNavigator), findsOneWidget);
    });

    testWidgets('Shows no breadcrumbs widget in summary tree', (tester) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Hello'),
        tester: tester,
      );

      final controller = inspectorTreeControllerFromNode(diagnosticNode);
      await tester.pumpWidget(wrap(
        InspectorTree(
          controller: controller,
          debuggerController: TestDebuggerController(),
          isSummaryTree: true,
        ),
      ));

      expect(find.byType(InspectorBreadcrumbNavigator), findsNothing);
    });
  });
}
