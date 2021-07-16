// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/trees.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TreeNode', () {
    test('depth', () {
      expect(testTreeNode.depth, equals(4));
      expect(treeNode2.depth, equals(1));
      expect(treeNode3.depth, equals(3));
    });

    test('isRoot', () {
      expect(treeNode0.isRoot, isTrue);
      expect(treeNode1.isRoot, isFalse);
      expect(treeNode5.isRoot, isFalse);
    });

    test('root', () {
      expect(treeNode2.root, equals(treeNode0));
    });

    test('level', () {
      expect(testTreeNode.level, equals(0));
      expect(treeNode2.level, equals(1));
      expect(treeNode6.level, equals(3));
    });

    test('expand and collapse', () {
      expect(testTreeNode.isExpanded, isFalse);
      testTreeNode.expand();
      expect(testTreeNode.isExpanded, isTrue);
      testTreeNode.collapse();
      expect(testTreeNode.isExpanded, isFalse);

      breadthFirstTraversal<TestTreeNode>(testTreeNode,
          action: (TreeNode node) {
        expect(node.isExpanded, isFalse);
      });

      testTreeNode.expandCascading();
      breadthFirstTraversal<TestTreeNode>(testTreeNode,
          action: (TreeNode node) {
        expect(node.isExpanded, isTrue);
      });

      testTreeNode.collapseCascading();
      breadthFirstTraversal<TestTreeNode>(testTreeNode,
          action: (TreeNode node) {
        expect(node.isExpanded, isFalse);
      });
    });

    test('shouldShow determines if each node is visible', () {
      final childTreeNodes = [
        treeNode1,
        treeNode2,
        treeNode3,
        treeNode4,
        treeNode5,
        treeNode6,
      ];
      void expectChildTreeNodesShouldShow(List<bool> expected) {
        expect(childTreeNodes.length, expected.length,
            reason: 'expected list of bool must have '
                '${childTreeNodes.length} elements');
        for (var i = 0; i < childTreeNodes.length; i++) {
          expect(childTreeNodes[i].shouldShow(), expected[i],
              reason: 'treeNode${i + 1}.shouldShow() did not match '
                  'the expected value.');
        }
      }

      expect(treeNode0.shouldShow(), true);
      expectChildTreeNodesShouldShow(
          [false, false, false, false, false, false]);
      treeNode0.expandCascading();
      treeNode5.collapse();
      expectChildTreeNodesShouldShow([true, true, true, true, true, false]);
      treeNode5.expand();
      treeNode3.collapse();
      expectChildTreeNodesShouldShow([true, true, true, false, false, false]);
      testTreeNode.collapseCascading();
    });

    test('addChild', () {
      final parent = TestTreeNode(0);
      final child = TestTreeNode(1);
      expect(parent.children, isEmpty);
      expect(child.parent, isNull);
      parent.addChild(child);
      expect(parent.children, isNotEmpty);
      expect(parent.children.first, equals(child));
      expect(child.parent, equals(parent));
    });

    test('containsChildWithCondition', () {
      expect(
        treeNode0.subtreeHasNodeWithCondition((TestTreeNode node) {
          return node == treeNode1;
        }),
        isTrue,
      );
      expect(
        treeNode0.subtreeHasNodeWithCondition((TestTreeNode node) {
          return node.children.length == 2;
        }),
        isTrue,
      );
      expect(
        treeNode0.subtreeHasNodeWithCondition((TestTreeNode node) {
          return node.isExpanded;
        }),
        isFalse,
      );
    });

    test('firstSubNodeAtLevel', () {
      expect(testTreeNode.firstChildNodeAtLevel(0), equals(treeNode0));
      expect(testTreeNode.firstChildNodeAtLevel(1), equals(treeNode1));
      expect(testTreeNode.firstChildNodeAtLevel(2), equals(treeNode4));
      expect(testTreeNode.firstChildNodeAtLevel(3), equals(treeNode6));
      expect(testTreeNode.firstChildNodeAtLevel(4), isNull);

      expect(treeNode3.firstChildNodeAtLevel(0), equals(treeNode3));
      expect(treeNode3.firstChildNodeAtLevel(1), equals(treeNode4));
      expect(treeNode3.firstChildNodeAtLevel(2), equals(treeNode6));
      expect(treeNode3.firstChildNodeAtLevel(3), isNull);
    });

    test('lastSubNodeAtLevel', () {
      expect(testTreeNode.lastChildNodeAtLevel(0), equals(treeNode0));
      expect(testTreeNode.lastChildNodeAtLevel(1), equals(treeNode3));
      expect(testTreeNode.lastChildNodeAtLevel(2), equals(treeNode5));
      expect(testTreeNode.lastChildNodeAtLevel(3), equals(treeNode9));
      expect(testTreeNode.lastChildNodeAtLevel(4), isNull);

      expect(treeNode3.lastChildNodeAtLevel(0), equals(treeNode3));
      expect(treeNode3.lastChildNodeAtLevel(1), equals(treeNode5));
      expect(treeNode3.lastChildNodeAtLevel(2), equals(treeNode9));
      expect(treeNode3.lastChildNodeAtLevel(3), isNull);
    });

    test('filterTree', () {
      final filteredTreeRoots =
          testTreeNode.filterTree((node) => node.id.isEven);
      expect(filteredTreeRoots.length, equals(1));
      final filteredTree = filteredTreeRoots.first;
      expect(filteredTree.toString(), equals('''
0
  2
  4
  6
  8
'''));
    });

    test('filterTree when root should be filtered out', () {
      final filteredTreeRoots =
          testTreeNode.filterTree((node) => node.id.isOdd);
      expect(filteredTreeRoots.length, equals(2));
      final firstRoot = filteredTreeRoots.first;
      final lastRoot = filteredTreeRoots.last;

      expect(firstRoot.toString(), equals('''
1
'''));
      expect(lastRoot.toString(), equals('''
3
  5
    7
    9
'''));
    });

    test('filterTree when zero nodes match', () {
      final filteredTreeRoots = testTreeNode.filterTree((node) => node.id > 10);
      expect(filteredTreeRoots, isEmpty);
    });

    test('filterTree when all nodes match', () {
      final filteredTreeRoots = testTreeNode.filterTree((node) => node.id < 10);
      expect(filteredTreeRoots.length, equals(1));
      final filteredTree = filteredTreeRoots.first;
      expect(filteredTree.toString(), equals('''
0
  1
  2
  3
    4
    5
      6
      7
      8
      9
'''));
    });
  });
}

final treeNode0 = TestTreeNode(0);
final treeNode1 = TestTreeNode(1);
final treeNode2 = TestTreeNode(2);
final treeNode3 = TestTreeNode(3);
final treeNode4 = TestTreeNode(4);
final treeNode5 = TestTreeNode(5);
final treeNode6 = TestTreeNode(6);
final treeNode7 = TestTreeNode(7);
final treeNode8 = TestTreeNode(8);
final treeNode9 = TestTreeNode(9);
final TestTreeNode testTreeNode = treeNode0
  ..addAllChildren([
    treeNode1,
    treeNode2,
    treeNode3
      ..addAllChildren([
        treeNode4,
        treeNode5
          ..addAllChildren([
            treeNode6,
            treeNode7,
            treeNode8,
            treeNode9,
          ]),
      ]),
  ]);

class TestTreeNode extends TreeNode<TestTreeNode> {
  TestTreeNode(this.id);

  final int id;

  @override
  TestTreeNode shallowCopy() => TestTreeNode(id);

  @override
  String toString() {
    final buf = StringBuffer();
    void writeNode(TestTreeNode node) {
      final indent = [for (int i = 0; i < node.level; i++) '  '].join();
      buf.writeln('$indent${node.id}');
      node.children.forEach(writeNode);
    }

    writeNode(this);
    return buf.toString();
  }
}
