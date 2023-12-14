// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer.dart';
import 'package:devtools_app/src/shared/flex_split_column.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/debugger/vm_service_object_tree.dart';
import '../test_infra/utils/tree_utils.dart';

void main() {
  group('Mock ProgramExplorer', () {
    late MockProgramExplorerController mockProgramExplorerController;

    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager();
      mockConnectedApp(
        fakeServiceConnection.serviceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      mockProgramExplorerController =
          createMockProgramExplorerControllerWithDefaults();
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
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
    late final FakeServiceConnectionManager fakeServiceConnection;

    setUpAll(() {
      fakeServiceConnection = FakeServiceConnectionManager();

      when(fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow)
          .thenReturn(false);
      when(fakeServiceConnection.serviceManager.connectedApp!.isDartWebAppNow)
          .thenReturn(false);

      final mockScriptManager = MockScriptManager();
      //`then` is used
      // ignore: discarded_futures
      when(mockScriptManager.getScript(any)).thenAnswer(
        (_) => Future<Script>.value(testScript),
      );

      setGlobal(ScriptManager, mockScriptManager);
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
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
          controller.rootObjectNodesInternal.add(libraryNode);
        },
      );
      final explorer = ProgramExplorer(controller: programExplorerController);
      await programExplorerController.initialize();
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
        expect(
          programExplorerController.outlineNodes.value
              .where((e) => e.isSelected),
          isEmpty,
        );

        // Select the library node and ensure the outline is populated.
        final libNodeFinder = find.text(libNode.name);
        expect(libNodeFinder, findsOneWidget);
        await tester.tap(libNodeFinder);
        await tester.pumpAndSettle();

        expect(programExplorerController.scriptSelection, libNode);
        expect(
          programExplorerController.outlineNodes.value
              .where((e) => e.isSelected),
          isEmpty,
        );

        // There should be three children total, one root with two children.
        expect(programExplorerController.outlineNodes.value.length, 1);
        expect(programExplorerController.outlineNodes.value.numNodes, 3);

        // Select one of them and check that the outline selection has been
        // updated.
        final outlineNode = programExplorerController.outlineNodes.value.first;
        final outlineNodeFinder = find.text(outlineNode.name);
        expect(outlineNodeFinder, findsOneWidget);
        await tester.tap(outlineNodeFinder);
        await tester.pumpAndSettle();

        expect(programExplorerController.scriptSelection, libNode);
        expect(
          programExplorerController.outlineNodes.value
              .singleWhereOrNull((e) => e.isSelected),
          outlineNode,
        );
      },
    );
  });
}
