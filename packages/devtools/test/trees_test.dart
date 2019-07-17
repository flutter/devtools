// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/trees.dart';
import 'package:test/test.dart';

void main() {
  group('TreeNode', () {
    test('depth', () {
      expect(testTreeNode.depth, equals(4));
      expect(treeNode2.depth, equals(3));
      expect(treeNode3.depth, equals(1));
    });

    test('root', () {
      expect(treeNode2.root, equals(treeNode0));
    });

    test('level', () {
      expect(testTreeNode.level, equals(0));
      expect(treeNode2.level, equals(1));
      expect(treeNode5.level, equals(3));
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
  });

  test('containsChildWithCondition', () {
    expect(
      treeNode0.containsChildWithCondition((TestTreeNode node) {
        return node == treeNode1;
      }),
      isTrue,
    );
    expect(
      treeNode0.containsChildWithCondition((TestTreeNode node) {
        return node.children.length == 2;
      }),
      isTrue,
    );
    expect(
      treeNode0.containsChildWithCondition((TestTreeNode node) {
        return node.isExpanded;
      }),
      isFalse,
    );
  });
}

final treeNode0 = TestTreeNode();
final treeNode1 = TestTreeNode();
final treeNode2 = TestTreeNode();
final treeNode3 = TestTreeNode();
final treeNode4 = TestTreeNode();
final treeNode5 = TestTreeNode();
final TreeNode testTreeNode = treeNode0
  ..addChild(treeNode1)
  ..addChild(
      treeNode2..addChild(treeNode3)..addChild(treeNode4..addChild(treeNode5)));

class TestTreeNode extends TreeNode<TestTreeNode> {}
