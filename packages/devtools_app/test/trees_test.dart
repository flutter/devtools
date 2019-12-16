// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/trees.dart';
import 'package:test/test.dart';

void main() {
  group('TreeNode', () {
    test('depth', () {
      expect(testTreeNode.depth, equals(4));
      expect(treeNode2.depth, equals(3));
      expect(treeNode3.depth, equals(1));
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
      expect(treeNode5.level, equals(3));
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
        treeNode5
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
      expectChildTreeNodesShouldShow([false, false, false, false, false]);
      treeNode0.expandCascading();
      treeNode4.collapse();
      expectChildTreeNodesShouldShow([true, true, true, true, false]);
      treeNode4.expand();
      treeNode2.collapse();
      expectChildTreeNodesShouldShow([true, true, false, false, false]);
      testTreeNode.collapseCascading();
    });

    test('addChild', () {
      final parent = TestTreeNode();
      final child = TestTreeNode();
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
      expect(testTreeNode.firstChildNodeAtLevel(2), equals(treeNode3));
      expect(testTreeNode.firstChildNodeAtLevel(3), equals(treeNode5));
      expect(testTreeNode.firstChildNodeAtLevel(4), isNull);

      expect(treeNode2.firstChildNodeAtLevel(0), equals(treeNode2));
      expect(treeNode2.firstChildNodeAtLevel(1), equals(treeNode3));
      expect(treeNode2.firstChildNodeAtLevel(2), equals(treeNode5));
      expect(treeNode2.firstChildNodeAtLevel(3), isNull);
    });

    test('lastSubNodeAtLevel', () {
      expect(testTreeNode.lastChildNodeAtLevel(0), equals(treeNode0));
      expect(testTreeNode.lastChildNodeAtLevel(1), equals(treeNode2));
      expect(testTreeNode.lastChildNodeAtLevel(2), equals(treeNode4));
      expect(testTreeNode.lastChildNodeAtLevel(3), equals(treeNode6));
      expect(testTreeNode.lastChildNodeAtLevel(4), isNull);

      expect(treeNode2.lastChildNodeAtLevel(0), equals(treeNode2));
      expect(treeNode2.lastChildNodeAtLevel(1), equals(treeNode4));
      expect(treeNode2.lastChildNodeAtLevel(2), equals(treeNode6));
      expect(treeNode2.lastChildNodeAtLevel(3), isNull);
    });
  });
}

final treeNode0 = TestTreeNode();
final treeNode1 = TestTreeNode();
final treeNode2 = TestTreeNode();
final treeNode3 = TestTreeNode();
final treeNode4 = TestTreeNode();
final treeNode5 = TestTreeNode();
final treeNode6 = TestTreeNode();
final TreeNode testTreeNode = treeNode0
  ..addAllChildren([
    treeNode1,
    treeNode2
      ..addAllChildren([
        treeNode3,
        treeNode4..addAllChildren([treeNode5, treeNode6]),
      ]),
  ]);

class TestTreeNode extends TreeNode<TestTreeNode> {}
