// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/primitives/trees.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TreeNode', () {
    test('depth', () {
      expect(testTreeNode.depth, equals(4));
      expect(treeNode1.depth, equals(1));
      expect(treeNode2.depth, equals(2));
      expect(treeNode3.depth, equals(3));
    });

    test('isRoot', () {
      expect(treeNode0.isRoot, isTrue);
      expect(treeNode1.isRoot, isFalse);
      expect(treeNode5.isRoot, isFalse);
    });

    test('root', () {
      expect(treeNode2.root, equals(treeNode0));
      expect(treeNode6.root, equals(treeNode0));
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

      breadthFirstTraversal<TestTreeNode>(
        testTreeNode,
        action: (TreeNode node) {
          expect(node.isExpanded, isFalse);
        },
      );

      testTreeNode.expandCascading();
      breadthFirstTraversal<TestTreeNode>(
        testTreeNode,
        action: (TreeNode node) {
          expect(node.isExpanded, isTrue);
        },
      );

      testTreeNode.collapseCascading();
      breadthFirstTraversal<TestTreeNode>(
        testTreeNode,
        action: (TreeNode node) {
          expect(node.isExpanded, isFalse);
        },
      );
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
        expect(
          childTreeNodes.length,
          expected.length,
          reason: 'expected list of bool must have '
              '${childTreeNodes.length} elements',
        );
        for (var i = 0; i < childTreeNodes.length; i++) {
          expect(
            childTreeNodes[i].shouldShow(),
            expected[i],
            reason: 'treeNode${i + 1}.shouldShow() did not match '
                'the expected value.',
          );
        }
      }

      expect(treeNode0.shouldShow(), true);
      expectChildTreeNodesShouldShow(
        [false, false, false, false, false, false],
      );
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

    test('nodesWithCondition', () {
      var nodes = testTreeNode.nodesWithCondition((TestTreeNode node) {
        return node.id.isEven;
      });
      var nodeIds = nodes.map((TestTreeNode node) => node.id).toList();
      expect(nodeIds, equals([0, 2, 10, 12, 4, 6, 8]));

      nodes = testTreeNode.nodesWithCondition((TestTreeNode node) {
        return node.tag == 'test-tag';
      });
      nodeIds = nodes.map((TestTreeNode node) => node.id).toList();
      expect(nodeIds, equals([0, 3, 9]));

      nodes = testTreeNode.nodesWithCondition((TestTreeNode node) {
        return node.parent?.id == 5;
      });
      nodeIds = nodes.map((TestTreeNode node) => node.id).toList();
      expect(nodeIds, equals([6, 7, 8, 9]));
    });

    test('shallowNodesWithCondition', () {
      var nodes = testTreeNode.shallowNodesWithCondition((TestTreeNode node) {
        return node.id.isEven;
      });
      var nodeIds = nodes.map((TestTreeNode node) => node.id).toList();
      expect(nodeIds, equals([0]));

      nodes = testTreeNode.shallowNodesWithCondition((TestTreeNode node) {
        return node.id.isEven && node.id != 0;
      });
      nodeIds = nodes.map((TestTreeNode node) => node.id).toList();
      expect(nodeIds, equals([2, 4, 6, 8]));

      nodes = testTreeNode.shallowNodesWithCondition((TestTreeNode node) {
        return node.id.isOdd;
      });
      nodeIds = nodes.map((TestTreeNode node) => node.id).toList();
      expect(nodeIds, equals([1, 11, 3]));
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
      expect(testTreeNode.firstChildNodeAtLevel(2), equals(treeNode10));
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
          testTreeNode.filterWhere((node) => node.id.isEven);
      expect(filteredTreeRoots.length, equals(1));
      final filteredTree = filteredTreeRoots.first;
      expect(
        filteredTree.toString(),
        equals(
          '''
0
  2
    10
    12
  4
  6
  8
''',
        ),
      );
    });

    test('filterTree when root should be filtered out', () {
      final filteredTreeRoots =
          testTreeNode.filterWhere((node) => node.id.isOdd);
      expect(filteredTreeRoots.length, equals(3));
      final firstRoot = filteredTreeRoots[0];
      final middleRoot = filteredTreeRoots[1];
      final lastRoot = filteredTreeRoots[2];

      expect(
        firstRoot.toString(),
        equals(
          '''
1
''',
        ),
      );
      expect(
        middleRoot.toString(),
        equals(
          '''
11
''',
        ),
      );
      expect(
        lastRoot.toString(),
        equals(
          '''
3
  5
    7
    9
''',
        ),
      );
    });

    test('filterTree when zero nodes match', () {
      final filteredTreeRoots =
          testTreeNode.filterWhere((node) => node.id > 15);
      expect(filteredTreeRoots, isEmpty);
    });

    test('filterTree when all nodes match', () {
      final filteredTreeRoots =
          testTreeNode.filterWhere((node) => node.id < 10);
      expect(filteredTreeRoots.length, equals(1));
      final filteredTree = filteredTreeRoots.first;
      expect(
        filteredTree.toString(),
        equals(
          '''
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
''',
        ),
      );
    });

    group('Tree traversal', () {
      late TraversalTestTreeNode treeNodeA;
      late TraversalTestTreeNode treeNodeB;
      late TraversalTestTreeNode treeNodeC;
      late TraversalTestTreeNode treeNodeD;
      late TraversalTestTreeNode treeNodeE;
      late TraversalTestTreeNode treeNodeF;
      late TraversalTestTreeNode treeNodeG;
      late TraversalTestTreeNode treeNodeH;
      late TraversalTestTreeNode treeNodeI;
      late TraversalTestTreeNode treeNodeJ;

      late TraversalTestTreeNode tree;

      setUp(() {
        /// Traversal test tree structure:
        ///
        /// [level 0]                A
        ///                      /   |   \
        /// [level 1]           B    C    D
        ///                   /   \       |
        /// [level 2]        E    F       G
        ///                 /            / \
        /// [level 3]      H            I   J
        ///
        /// BFS traversal order: A, B, C, D, E, F, G, H, I, J
        /// DFS traversal order: A, B, E, H, F, C, D, G, I, J

        treeNodeA = TraversalTestTreeNode('A');
        treeNodeB = TraversalTestTreeNode('B');
        treeNodeC = TraversalTestTreeNode('C');
        treeNodeD = TraversalTestTreeNode('D');
        treeNodeE = TraversalTestTreeNode('E');
        treeNodeF = TraversalTestTreeNode('F');
        treeNodeG = TraversalTestTreeNode('G');
        treeNodeH = TraversalTestTreeNode('H');
        treeNodeI = TraversalTestTreeNode('I');
        treeNodeJ = TraversalTestTreeNode('J');

        tree = treeNodeA
          ..addAllChildren(
            [
              treeNodeB
                ..addAllChildren(
                  [
                    treeNodeE
                      ..addAllChildren([
                        treeNodeH,
                      ]),
                    treeNodeF,
                  ],
                ),
              treeNodeC,
              treeNodeD
                ..addAllChildren([
                  treeNodeG
                    ..addAllChildren([
                      treeNodeI,
                      treeNodeJ,
                    ]),
                ]),
            ],
          );
      });

      group('BFS', () {
        test('traverses tree in correct order', () {
          var visitedCount = 0;
          breadthFirstTraversal<TraversalTestTreeNode>(
            tree,
            action: (node) => node.setVisitedOrder(++visitedCount),
          );
          // BFS order: A, B, C, D, E, F, G, H, I, J
          expect(treeNodeA.visitedOrder, equals(1));
          expect(treeNodeB.visitedOrder, equals(2));
          expect(treeNodeC.visitedOrder, equals(3));
          expect(treeNodeD.visitedOrder, equals(4));
          expect(treeNodeE.visitedOrder, equals(5));
          expect(treeNodeF.visitedOrder, equals(6));
          expect(treeNodeG.visitedOrder, equals(7));
          expect(treeNodeH.visitedOrder, equals(8));
          expect(treeNodeI.visitedOrder, equals(9));
          expect(treeNodeJ.visitedOrder, equals(10));
        });

        test('finds the correct node', () {
          final node = breadthFirstTraversal<TraversalTestTreeNode>(
            tree,
            returnCondition: (node) => node.id == 'H',
          )!;
          expect(node.id, equals('H'));
        });
      });

      group('DFS', () {
        test('traverses tree in correct order', () {
          var visitedCount = 0;
          depthFirstTraversal<TraversalTestTreeNode>(
            tree,
            action: (node) => node.setVisitedOrder(++visitedCount),
          );
          // DFS order: A, B, E, H, F, C, D, G, I, J
          expect(treeNodeA.visitedOrder, equals(1));
          expect(treeNodeB.visitedOrder, equals(2));
          expect(treeNodeE.visitedOrder, equals(3));
          expect(treeNodeH.visitedOrder, equals(4));
          expect(treeNodeF.visitedOrder, equals(5));
          expect(treeNodeC.visitedOrder, equals(6));
          expect(treeNodeD.visitedOrder, equals(7));
          expect(treeNodeG.visitedOrder, equals(8));
          expect(treeNodeI.visitedOrder, equals(9));
          expect(treeNodeJ.visitedOrder, equals(10));
        });

        test('finds the correct node', () {
          final node = depthFirstTraversal<TraversalTestTreeNode>(
            tree,
            returnCondition: (node) => node.id == 'H',
          )!;
          expect(node.id, equals('H'));
        });

        test('explores correct children', () {
          var visitedCount = 0;
          depthFirstTraversal<TraversalTestTreeNode>(
            tree,
            action: (node) => node.setVisitedOrder(++visitedCount),
            exploreChildrenCondition: (node) => node.id != 'B',
          );
          // DFS order: A, B, [skip] E, H, F, [end skip], C, D, G, I, J
          expect(treeNodeA.visitedOrder, equals(1));
          expect(treeNodeB.visitedOrder, equals(2));
          expect(treeNodeE.visitedOrder, equals(-1));
          expect(treeNodeH.visitedOrder, equals(-1));
          expect(treeNodeF.visitedOrder, equals(-1));
          expect(treeNodeC.visitedOrder, equals(3));
          expect(treeNodeD.visitedOrder, equals(4));
          expect(treeNodeG.visitedOrder, equals(5));
          expect(treeNodeI.visitedOrder, equals(6));
          expect(treeNodeJ.visitedOrder, equals(7));
        });
      });
    });
  });
}

final treeNode0 = TestTreeNode(0, tag: 'test-tag');
final treeNode1 = TestTreeNode(1);
final treeNode2 = TestTreeNode(2);
final treeNode3 = TestTreeNode(3, tag: 'test-tag');
final treeNode4 = TestTreeNode(4);
final treeNode5 = TestTreeNode(5);
final treeNode6 = TestTreeNode(6);
final treeNode7 = TestTreeNode(7);
final treeNode8 = TestTreeNode(8);
final treeNode9 = TestTreeNode(9, tag: 'test-tag');
final treeNode10 = TestTreeNode(10);
final treeNode11 = TestTreeNode(11);
final treeNode12 = TestTreeNode(12);
final testTreeNode = treeNode0
  ..addAllChildren([
    treeNode1,
    treeNode2
      ..addAllChildren([
        treeNode10,
        treeNode11,
        treeNode12,
      ]),
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
  TestTreeNode(this.id, {this.tag});

  final int id;

  final String? tag;

  @override
  TestTreeNode shallowCopy() => TestTreeNode(id);

  @override
  String toString() {
    final buf = StringBuffer();
    void writeNode(TestTreeNode node) {
      final indent = '  ' * node.level;
      buf.writeln('$indent${node.id}');
      node.children.forEach(writeNode);
    }

    writeNode(this);
    return buf.toString();
  }
}

class TraversalTestTreeNode extends TreeNode<TraversalTestTreeNode> {
  TraversalTestTreeNode(this.id);

  final String id;

  int get visitedOrder => _visitedOrder;
  int _visitedOrder = -1;

  @override
  TraversalTestTreeNode shallowCopy() => TraversalTestTreeNode(id);

  void setVisitedOrder(int order) {
    _visitedOrder = order;
  }
}
