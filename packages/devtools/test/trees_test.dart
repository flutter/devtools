// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/trees.dart';
import 'package:test/test.dart';

void main() {
  group('TreeNode', () {
    test('depth', () {
      expect(testTreeNode.depth, equals(4));
      expect(treeNode2.depth, equals(1));
      expect(treeNode3.depth, equals(2));
    });

    test('root', () {
      expect(treeNode2.root, equals(treeNode0));
    });

    test('level', () {
      expect(testTreeNode.level, equals(0));
      expect(treeNode2.level, equals(2));
      expect(treeNode5.level, equals(3));
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

final treeNode0 = TreeNode();
final treeNode1 = TreeNode();
final treeNode2 = TreeNode();
final treeNode3 = TreeNode();
final treeNode4 = TreeNode();
final treeNode5 = TreeNode();
final TreeNode testTreeNode = treeNode0
  ..addChild(treeNode1
    ..addChild(treeNode2)
    ..addChild(treeNode3..addChild(treeNode4)..addChild(treeNode5)));
