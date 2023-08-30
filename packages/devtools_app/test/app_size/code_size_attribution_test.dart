// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/app_size/code_size_attribution.dart';
import 'package:devtools_app/src/shared/table/table.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_snapshot_analysis/precompiler_trace.dart';
import 'package:vm_snapshot_analysis/program_info.dart';

import '../test_infra/test_data/app_size/precompiler_trace.dart';

void main() {
  late CallGraph callGraph;

  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(IdeTheme, IdeTheme());
    callGraph = generateCallGraphWithDominators(
      precompilerTrace,
      NodeType.packageNode,
    );
  });

  group('CallGraphWithDominators', () {
    late CallGraphWithDominators callGraphWithDominators;
    setUp(() {
      callGraphWithDominators = CallGraphWithDominators(
        callGraphRoot: callGraph.root,
      );
    });

    testWidgets(
      'builds dominator tree by default',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(callGraphWithDominators));
        expect(find.text('Dominator Tree'), findsOneWidget);
        expect(find.text('Call Graph'), findsNothing);
        expect(find.byType(DominatorTree), findsOneWidget);
        expect(find.byType(CallGraphView), findsNothing);
      },
    );

    testWidgets('builds call graph', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(callGraphWithDominators));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Dominator Tree'), findsNothing);
      expect(find.text('Call Graph'), findsOneWidget);
      expect(find.byType(DominatorTree), findsNothing);
      expect(find.byType(CallGraphView), findsOneWidget);
    });

    testWidgets('can switch views', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(callGraphWithDominators));
      expect(find.text('Dominator Tree'), findsOneWidget);
      expect(find.text('Call Graph'), findsNothing);
      expect(find.byType(DominatorTree), findsOneWidget);
      expect(find.byType(CallGraphView), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Dominator Tree'), findsNothing);
      expect(find.text('Call Graph'), findsOneWidget);
      expect(find.byType(DominatorTree), findsNothing);
      expect(find.byType(CallGraphView), findsOneWidget);
    });
  });

  group('CallGraphView', () {
    late CallGraphView callGraphView;
    setUp(() {
      callGraphView = CallGraphView(node: callGraph.root);
    });

    testWidgets('builds content for root', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(callGraphView));

      expect(find.byType(FlatTable<CallGraphNode>), findsNWidgets(2));
      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);

      final fromTable = find
          .byType(FlatTable<CallGraphNode>)
          .evaluate()
          .first
          .widget as FlatTable;
      expect(fromTable.data, isEmpty);

      final toTable = find
          .byType(FlatTable<CallGraphNode>)
          .evaluate()
          .last
          .widget as FlatTable;
      expect(toTable.data.length, equals(17));
    });

    testWidgets('re-roots on selection', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(callGraphView));

      expect(find.byType(FlatTable<CallGraphNode>), findsNWidgets(2));
      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);

      var fromTable = find
          .byType(FlatTable<CallGraphNode>)
          .evaluate()
          .first
          .widget as FlatTable;
      expect(fromTable.data, isEmpty);

      var toTable = find.byType(FlatTable<CallGraphNode>).evaluate().last.widget
          as FlatTable;
      expect(toTable.data.length, equals(17));

      // Tap to re-root call graph.
      await tester.tap(find.richText('dart:math'));
      await tester.pumpAndSettle();

      fromTable = find.byType(FlatTable<CallGraphNode>).evaluate().first.widget
          as FlatTable;
      expect(fromTable.data.length, equals(3));

      toTable = find.byType(FlatTable<CallGraphNode>).evaluate().last.widget
          as FlatTable;
      expect(toTable.data.length, equals(1));
    });
  });

  group('DominatorTree', () {
    late DominatorTree dominatorTree;

    setUp(() {
      dominatorTree = DominatorTree(
        dominatorTreeRoot: DominatorTreeNode.from(callGraph.root.dominatorRoot),
        selectedNode: callGraph.root,
      );
    });

    testWidgets('builds content for root', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(dominatorTree));

      expect(find.byKey(DominatorTree.dominatorTreeTableKey), findsOneWidget);
      expect(find.text('Package'), findsOneWidget);

      final treeTable = find
          .byKey(DominatorTree.dominatorTreeTableKey)
          .evaluate()
          .first
          .widget as TreeTable;
      expect(treeTable.dataRoots.length, equals(1));

      final root = treeTable.dataRoots.first;
      expect(root.isExpanded, isTrue);
      expect(root.children.length, equals(18));

      for (DominatorTreeNode child in root.children.cast<DominatorTreeNode>()) {
        expect(child.isExpanded, isFalse);
      }
    });

    testWidgets('expands tree to selected node', (WidgetTester tester) async {
      dominatorTree = DominatorTree(
        dominatorTreeRoot: DominatorTreeNode.from(callGraph.root.dominatorRoot),
        selectedNode: callGraph.root.dominated
            .firstWhere((node) => node.display == 'package:code_size_package'),
      );
      await tester.pumpWidget(wrap(dominatorTree));
      final treeTable = find
          .byKey(DominatorTree.dominatorTreeTableKey)
          .evaluate()
          .first
          .widget as TreeTable;

      final root = treeTable.dataRoots.first;
      expect(root.isExpanded, isTrue);
      expect(root.children.length, equals(18));

      // Only the selected node should be expanded.
      for (DominatorTreeNode child in root.children.cast<DominatorTreeNode>()) {
        expect(
          child.isExpanded,
          child.callGraphNode.display == 'package:code_size_package',
        );
      }

      // The selected node's children should not be expanded.
      final selectedNode = root.children.first as DominatorTreeNode;
      expect(
        selectedNode.callGraphNode.display,
        equals('package:code_size_package'),
      );
      expect(selectedNode.children.length, equals(3));

      for (DominatorTreeNode child in selectedNode.children) {
        expect(child.isExpanded, isFalse);
      }
    });
  });
}
