// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/trees.dart';
import 'package:test/test.dart';

void main() {
  group('TreeNode', () {
    test('depth', () {
      expect(testTreeNode.depth, equals(4));
      expect(treeNode_2.depth, equals(1));
      expect(treeNode_3.depth, equals(2));
    });

    test('root', () {
      expect(treeNode_2.root, equals(treeNode_0));
    });

    test('level', () {
      expect(testTreeNode.level, equals(0));
      expect(treeNode_2.level, equals(2));
      expect(treeNode_5.level, equals(3));
    });

    test('addChild', () {
      final parent = TreeNode();
      final child = TreeNode();
      expect(parent.children, isEmpty);
      expect(child.parent, isNull);
      parent.addChild(child);
      expect(parent.children, isNotEmpty);
      expect(parent.children.first, equals(child));
      expect(child.parent, equals(parent));
    });
  });
}

final treeNode_0 = TreeNode();
final treeNode_1 = TreeNode();
final treeNode_2 = TreeNode();
final treeNode_3 = TreeNode();
final treeNode_4 = TreeNode();
final treeNode_5 = TreeNode();
final TreeNode testTreeNode = treeNode_0
  ..addChild(treeNode_1
    ..addChild(treeNode_2)
    ..addChild(treeNode_3..addChild(treeNode_4)..addChild(treeNode_5)));
