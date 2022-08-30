// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/primitives/listenable.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/flex_split_column.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_data/vm_service_object_tree.dart';
import '../test_utils/tree_utils.dart';

void main() {
  group('Mock ProgramExplorer', () {
    late MockProgramExplorerController mockProgramExplorerController;

    setUp(() {
      final fakeServiceManager = FakeServiceManager();
      mockConnectedApp(
        fakeServiceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      mockProgramExplorerController =
          createMockProgramExplorerControllerWithDefaults();
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(ServiceConnectionManager, fakeServiceManager);
    });

    testWidgets('builds when not initialized', (WidgetTester tester) async {
      when(mockProgramExplorerController.initialized)
          .thenReturn(const FixedValueListenable(false));
      await tester.pumpWidget(
        wrap(
          ProgramExplorer(controller: mockProgramExplorerController),
        ),
      );
      expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
    });

    testWidgets('builds when initialized', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          ProgramExplorer(controller: mockProgramExplorerController),
        ),
      );
      expect(find.byType(AreaPaneHeader), findsNWidgets(2));
      expect(find.text('File Explorer'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.byType(FlexSplitColumn), findsOneWidget);
    });
  });

  // TODO(https://github.com/flutter/devtools/issues/4227): write more thorough
  // tests for the ProgramExplorer widget.

  group('Fake ProgramExplorer', () {
    late final FakeServiceManager fakeServiceManager;

    setUpAll(() {
      fakeServiceManager = FakeServiceManager();

      when(fakeServiceManager.connectedApp!.isProfileBuildNow)
          .thenReturn(false);
      when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);

      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());
    });

    Future<TestProgramExplorerController> initializeProgramExplorer(
      WidgetTester tester,
    ) async {
      final programExplorerController = TestProgramExplorerController(
        initializer: (controller) {
          final libraryNode =
              VMServiceObjectNode(controller, 'fooLib', testLib);
          libraryNode.script = testScript;
          libraryNode.location = ScriptLocation(testScript);
          controller.rootObjectNodesOverride.add(libraryNode);
        },
      );
      final explorer = ProgramExplorer(controller: programExplorerController);
      programExplorerController.initialize();
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: explorer.build,
          ),
        ),
      );
      expect(programExplorerController.initialized.value, true);
      expect(programExplorerController.rootObjectNodes.value.numNodes, 1);
      return programExplorerController;
    }

    testWidgets('correctly builds nodes', (WidgetTester tester) async {
      final programExplorerController = await initializeProgramExplorer(tester);
      final libNode = programExplorerController.rootObjectNodes.value.first;
      final outline = (await libNode.outline)!;

      // The outline should only contain a single Class node.
      expect(outline.length, 1);
      final clsNode = outline.first;
      expect(clsNode.object, const TypeMatcher<Class>());
      expect(clsNode.name, testClassRef.name);

      // The class should contain a function and a field.
      expect(clsNode.children.length, 2);
      for (final child in clsNode.children) {
        if (child.object is Func) {
          expect(child.object, testFunction);
        } else if (child.object is Field) {
          expect(child.object, testField);
        } else {
          fail('Unexpected node type: ${child.object.runtimeType}');
        }
      }
    });

    testWidgets(
      'selection',
      (WidgetTester tester) async {
        final programExplorerController =
            await initializeProgramExplorer(tester);
        final libNode = programExplorerController.rootObjectNodes.value.first;

        // No node has been selected yet, so the outline should be empty.
        expect(programExplorerController.outlineNodes.value.isEmpty, true);
        expect(programExplorerController.scriptSelection, isNull);
        expect(programExplorerController.outlineSelection.value, isNull);

        // Select the library node and ensure the outline is populated.
        await programExplorerController.selectNode(libNode);
        expect(programExplorerController.scriptSelection, libNode);
        expect(programExplorerController.outlineSelection.value, isNull);

        // There should be three children total, one root with two children.
        expect(programExplorerController.outlineNodes.value.length, 1);
        expect(programExplorerController.outlineNodes.value.numNodes, 3);

        // Select one of them and check that the outline selection has been
        // updated.
        final outlineNode = programExplorerController.outlineNodes.value.first;
        programExplorerController.selectOutlineNode(outlineNode);
        expect(programExplorerController.scriptSelection, libNode);
        expect(programExplorerController.outlineSelection.value, outlineNode);

        // Ensure that the outline view can be reset.
        programExplorerController.resetOutline();
        expect(programExplorerController.scriptSelection, libNode);
        expect(programExplorerController.outlineSelection.value, isNull);
      },
    );
  });
}
