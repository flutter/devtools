// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/debugger_controller.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/inspector/inspector_tree_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

import 'support/inspector_tree.dart';
import 'support/mocks.dart';
import 'support/utils.dart';
import 'support/wrappers.dart';

void main() {
  FakeServiceManager fakeServiceManager;

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);

    setGlobal(ServiceConnectionManager, fakeServiceManager);
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
      final debuggerController = DebuggerController();
      await tester.pumpWidget(wrap(InspectorTree(
        controller: controller,
        debuggerController: debuggerController,
      )));

      expect(controller.getRow(const Offset(0, -100.0)), isNull);
      expect(controller.getRowOffset(-1), equals(0));

      expect(controller.getRow(const Offset(0, 0.0)), isNull);
      expect(controller.getRowOffset(0), equals(0));

      controller.root = InspectorTreeNode()..appendChild(InspectorTreeNode());
      await tester.pumpWidget(wrap(InspectorTree(
        controller: controller,
        debuggerController: debuggerController,
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
        debuggerController: DebuggerController(),
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
        debuggerController: DebuggerController(),
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
          debuggerController: DebuggerController(),
        )),
      );

      expect(find.richText('Text: "Multiline text  content"'), findsOneWidget);
    });
  });
}
