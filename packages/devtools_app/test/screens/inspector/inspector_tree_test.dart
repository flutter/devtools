// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    mockConnectedApp(fakeServiceConnection.serviceManager.connectedApp!);

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
        debugger: debuggerController,
        InspectorTree(
          controller: inspectorController,
          treeController: treeController,
        ),
      ),
    );
  }

  InspectorTreeController buildTreeController({
    required void Function({bool notifyFlutterInspector}) onSelectionChange,
  }) {
    return InspectorTreeController()
      ..config = InspectorTreeConfig(
        onNodeAdded: (_, _) {},
        onClientActiveChange: (_) {},
        onSelectionChange: onSelectionChange,
      )
      ..root = (InspectorTreeNode()
        ..appendChild(InspectorTreeNode())
        ..appendChild(InspectorTreeNode()));
  }

  List<InspectorTreeNode> visibleNodes(InspectorTreeController controller) {
    return controller.rowsInTree.value.map((row) => row!.node).toList();
  }

  group('InspectorTreeController', () {
    testWidgets('Row with negative index regression test', (
      WidgetTester tester,
    ) async {
      final treeController = InspectorTreeController()
        ..config = InspectorTreeConfig(
          onNodeAdded: (_, _) {},
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

    testWidgets('Strips new lines from text preview', (
      WidgetTester tester,
    ) async {
      final diagnosticNode = await widgetToInspectorTreeDiagnosticsNode(
        widget: const Text('Multiline\ntext\n\ncontent'),
        tester: tester,
      );

      final treeController = inspectorTreeControllerFromNode(diagnosticNode);
      await pumpInspectorTree(tester, treeController: treeController);

      expect(find.richText('Text: "Multiline text  content"'), findsOneWidget);
    });
  });

  group('InspectorTreeController keyboard navigation', () {
    testWidgets(
      'navigateDown triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        treeController.navigateDown();
        await tester.pump();

        expect(capturedNotify, isTrue);
      },
    );

    testWidgets(
      'navigateUp triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        // Move selection to the second row so navigateUp has somewhere to go.
        treeController.navigateDown();
        await tester.pump();
        treeController.navigateDown();
        await tester.pump();

        capturedNotify = null;
        treeController.navigateUp();
        await tester.pump();

        expect(capturedNotify, isTrue);
      },
    );

    testWidgets(
      'navigateRight triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        final root = treeController.root!;
        final firstChild = root.children.first;
        root.isExpanded = false;
        treeController.setSelectedNode(root);

        // First right-arrow navigation expands the selected node.
        capturedNotify = null;
        treeController.navigateRight();
        await tester.pump();

        expect(root.isExpanded, isTrue);
        expect(treeController.selection, root);
        expect(capturedNotify, isNull);

        // Once expanded, right-arrow navigation selects the next visible row.
        treeController.navigateRight();
        await tester.pump();

        expect(treeController.selection, firstChild);
        expect(capturedNotify, isTrue);
      },
    );

    testWidgets(
      'navigateLeft triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        final root = treeController.root!;
        final firstChild = root.children.first..isExpanded = false;
        treeController.setSelectedNode(firstChild);

        capturedNotify = null;
        treeController.navigateLeft();
        await tester.pump();

        expect(treeController.selection, root);
        expect(capturedNotify, isTrue);
      },
    );
  });

  group('InspectorTree keyboard events', () {
    testWidgets(
      'arrowDown key triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(capturedNotify, isTrue);
      },
    );

    testWidgets(
      'arrowUp key triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        // Move selection to the second row first.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        capturedNotify = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(capturedNotify, isTrue);
      },
    );

    testWidgets(
      'arrowRight key triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        final root = treeController.root!;
        final firstChild = root.children.first;
        root.isExpanded = false;
        treeController.setSelectedNode(root);

        // First arrowRight expands the selected node.
        capturedNotify = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        expect(root.isExpanded, isTrue);
        expect(treeController.selection, root);
        expect(capturedNotify, isNull);

        // Once expanded, arrowRight selects the next visible row.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        expect(treeController.selection, firstChild);
        expect(capturedNotify, isTrue);
      },
    );

    testWidgets(
      'arrowLeft key triggers onSelectionChange with notifyFlutterInspector true',
      (WidgetTester tester) async {
        bool? capturedNotify;
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {
            capturedNotify = notifyFlutterInspector;
          },
        );

        await pumpInspectorTree(tester, treeController: treeController);

        final root = treeController.root!;
        final firstChild = root.children.first..isExpanded = false;
        treeController.setSelectedNode(firstChild);

        capturedNotify = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        expect(treeController.selection, root);
        expect(capturedNotify, isTrue);
      },
    );

    testWidgets(
      'arrowLeft key collapses selected node without removing previous rows',
      (WidgetTester tester) async {
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {},
        );

        final root = treeController.root!;
        final previousSibling = root.children.first;
        final selectedSibling = root.children.last
          ..appendChild(InspectorTreeNode())
          ..appendChild(InspectorTreeNode());
        final selectedSiblingFirstChild = selectedSibling.children.first;
        final selectedSiblingSecondChild = selectedSibling.children.last;
        treeController.root = root;
        treeController.setSelectedNode(selectedSibling);

        await pumpInspectorTree(tester, treeController: treeController);

        expect(visibleNodes(treeController), [
          root,
          previousSibling,
          selectedSibling,
          selectedSiblingFirstChild,
          selectedSiblingSecondChild,
        ]);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        expect(selectedSibling.isExpanded, isFalse);
        expect(treeController.selection, selectedSibling);
        expect(visibleNodes(treeController), [
          root,
          previousSibling,
          selectedSibling,
        ]);
      },
    );

    testWidgets(
      'arrowLeft key on collapsed child selects parent without changing rows',
      (WidgetTester tester) async {
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {},
        );

        final root = treeController.root!;
        final previousSibling = root.children.first;
        final parent = root.children.last
          ..appendChild(InspectorTreeNode())
          ..appendChild(InspectorTreeNode());
        final child = parent.children.first..isExpanded = false;
        final nextSibling = parent.children.last;
        treeController.root = root;
        treeController.setSelectedNode(child);

        await pumpInspectorTree(tester, treeController: treeController);

        final rowsBeforeArrowLeft = visibleNodes(treeController);
        expect(rowsBeforeArrowLeft, [
          root,
          previousSibling,
          parent,
          child,
          nextSibling,
        ]);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        expect(treeController.selection, parent);
        expect(visibleNodes(treeController), rowsBeforeArrowLeft);
      },
    );

    testWidgets('arrowLeft key does not put the tree into the loading state', (
      WidgetTester tester,
    ) async {
      final treeController = buildTreeController(
        onSelectionChange: ({bool notifyFlutterInspector = false}) {},
      );

      await pumpInspectorTree(tester, treeController: treeController);

      final root = treeController.root!;
      treeController.setSelectedNode(root);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // After collapsing the root, only the root row remains visible. The
      // tree must still render that row instead of a loading indicator.
      expect(find.byType(CenteredCircularProgressIndicator), findsNothing);
      expect(visibleNodes(treeController), [root]);
    });

    testWidgets(
      'onSelectNode does not re-expand a node the user just collapsed via '
      'the arrow-left key',
      (WidgetTester tester) async {
        // Regression test: clicking a still-visible row used to call
        // expandPath on the clicked node, which re-expanded the clicked node
        // itself and undid any subtree collapse the user had just performed
        // via the arrow-left key.
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {},
        );

        final root = treeController.root!;
        final firstChild = root.children.first
          ..appendChild(InspectorTreeNode())
          ..appendChild(InspectorTreeNode());
        final secondChild = root.children.last;
        treeController.root = root;
        treeController.setSelectedNode(firstChild);

        await pumpInspectorTree(tester, treeController: treeController);

        // Collapse [firstChild] so its grandchildren are hidden.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(firstChild.isExpanded, isFalse);
        expect(visibleNodes(treeController), [root, firstChild, secondChild]);

        // Re-selecting the just-collapsed row must not re-expand it.
        treeController.onSelectNode(firstChild);
        await tester.pump();

        expect(firstChild.isExpanded, isFalse);
        expect(visibleNodes(treeController), [root, firstChild, secondChild]);
      },
    );

    testWidgets(
      'onSelectNode does not re-expand a node the user just collapsed by '
      'clicking it',
      (WidgetTester tester) async {
        // Regression test: clicking a row used to call expandPath on the
        // clicked node itself, so a user could not select a node in its
        // collapsed state.
        final treeController = buildTreeController(
          onSelectionChange: ({bool notifyFlutterInspector = false}) {},
        );

        final root = treeController.root!;
        final firstChild = root.children.first
          ..appendChild(InspectorTreeNode())
          ..isExpanded = false;
        treeController.root = root;

        await pumpInspectorTree(tester, treeController: treeController);

        treeController.onSelectNode(firstChild);
        await tester.pump();

        expect(treeController.selection, firstChild);
        expect(firstChild.isExpanded, isFalse);
      },
    );
  });

  group('InspectorTree loading indicator', () {
    testWidgets(
      'shows a loading indicator while the initial tree load is in progress',
      (WidgetTester tester) async {
        // Before the first inspector tree load completes, a tree with at most
        // a single row represents the "still loading" state and should render
        // a progress indicator instead of the bare row.
        inspectorController.firstInspectorTreeLoadCompleted = false;

        final treeController = InspectorTreeController()
          ..config = InspectorTreeConfig(
            onNodeAdded: (_, _) {},
            onClientActiveChange: (_) {},
          )
          ..root = InspectorTreeNode();

        await pumpInspectorTree(tester, treeController: treeController);

        expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'renders a single-row tree (no spinner) after the initial load has '
      'completed',
      (WidgetTester tester) async {
        // Regression test: collapsing the root via the arrow-left key shrinks
        // the visible rows down to a single row. Before the fix, the
        // [InspectorTree] widget treated a one-row tree as "loading" and
        // showed a spinner, hiding the user's [root] row.
        inspectorController.firstInspectorTreeLoadCompleted = true;

        final treeController = InspectorTreeController()
          ..config = InspectorTreeConfig(
            onNodeAdded: (_, _) {},
            onClientActiveChange: (_) {},
          )
          ..root = InspectorTreeNode();

        await pumpInspectorTree(tester, treeController: treeController);

        expect(find.byType(CenteredCircularProgressIndicator), findsNothing);
      },
    );
  });
}
