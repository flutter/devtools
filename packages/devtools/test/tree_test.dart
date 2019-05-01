// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
import 'dart:html';

import 'package:devtools/src/ui/custom.dart';
import 'package:devtools/src/ui/elements.dart';
import 'package:devtools/src/ui/trees.dart';
import 'package:test/test.dart';

import 'integration_tests/util.dart';

void main() {
  group('tree views', () {
    TestStringTreeView tree;

    setUp(() async {
      tree = new TestStringTreeView();
      document.body.append(tree.element);
      await window.animationFrame;
      tree.element.focus();
    });
    tearDown(() => tree?.element?.remove());

    test('renders only top level initially', () {
      final textTree = tree.getTextTree();
      const expectedTree = '''
- Item 1
- Item 2
- Item 3
''';
      expect(textTree, equals(expectedTree));
    });

    test('includes children when expanded', () async {
      tree.treeNodes[1].expand();
      await shortDelay();
      final textTree = tree.getTextTree();
      const expectedTree = '''
- Item 1
- Item 2
  - Item 2.1
  - Item 2.2
  - Item 2.3
- Item 3
''';
      expect(textTree, equals(expectedTree));
    });

    test('hides children when collapsed', () async {
      tree.treeNodes[1].expand();
      await shortDelay();
      tree.treeNodes[1].collapse();
      await shortDelay();
      final textTree = tree.getTextTree();
      const expectedTree = '''
- Item 1
- Item 2
- Item 3
''';
      expect(textTree, equals(expectedTree));
    });

    group('keyboard navigation', () {
      test('DOWN moves selection to next sibling if not expanded', () async {
        tree.select(tree.treeNodes.first);
        expect(tree.getTextTree(), equals('''
- Item 1 ***
- Item 2
- Item 3
'''));

        tree.moveDown();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
- Item 3
'''));
      });

      test('DOWN moves selection to first child if expanded', () async {
        tree.select(tree.treeNodes.first);
        tree.selectedItem.expand();
        await shortDelay();
        expect(tree.getTextTree(), equals('''
- Item 1 ***
  - Item 1.1
  - Item 1.2
  - Item 1.3
- Item 2
- Item 3
'''));

        tree.moveDown();
        expect(tree.getTextTree(), equals('''
- Item 1
  - Item 1.1 ***
  - Item 1.2
  - Item 1.3
- Item 2
- Item 3
'''));
      });
      test('DOWN sticks to the last item if nothing below it', () async {
        tree.select(tree.treeNodes.last);
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
- Item 3 ***
'''));

        tree.moveDown();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
- Item 3 ***
'''));
      });

      test('Down selects the first visible item if there is no selection',
          () async {
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
- Item 3
'''));

        tree.moveDown();
        expect(tree.getTextTree(), equals('''
- Item 1 ***
- Item 2
- Item 3
'''));
      });

      test('UP moves selection to previous sibling if not expanded', () async {
        tree.select(tree.treeNodes[1]);
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
- Item 3
'''));

        tree.moveUp();
        expect(tree.getTextTree(), equals('''
- Item 1 ***
- Item 2
- Item 3
'''));
      });

      test('UP moves selection to last child of previous sibling if expanded',
          () async {
        tree.treeNodes[0].expand();
        await shortDelay();
        tree.select(tree.treeNodes[1]);
        expect(tree.getTextTree(), equals('''
- Item 1
  - Item 1.1
  - Item 1.2
  - Item 1.3
- Item 2 ***
- Item 3
'''));

        tree.moveUp();
        expect(tree.getTextTree(), equals('''
- Item 1
  - Item 1.1
  - Item 1.2
  - Item 1.3 ***
- Item 2
- Item 3
'''));
      });
      test('UP sticks to the first item if nothing above it', () async {
        tree.select(tree.treeNodes.first);
        expect(tree.getTextTree(), equals('''
- Item 1 ***
- Item 2
- Item 3
'''));

        tree.moveUp();
        expect(tree.getTextTree(), equals('''
- Item 1 ***
- Item 2
- Item 3
'''));
      });

      test('UP selects the last visible item if there is no selection',
          () async {
        tree.treeNodes.last.expand();
        await shortDelay();
        tree.treeNodes.last.children.last.expand();
        await shortDelay();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
- Item 3
  - Item 3.1
  - Item 3.2
  - Item 3.3
    - Item 3.3.1
    - Item 3.3.2
    - Item 3.3.3
'''));

        tree.moveUp();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
- Item 3
  - Item 3.1
  - Item 3.2
  - Item 3.3
    - Item 3.3.1
    - Item 3.3.2
    - Item 3.3.3 ***
'''));
      });

      test('LEFT does nothing for level=1', () {
        tree.select(tree.treeNodes[1]);
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
- Item 3
'''));

        tree.moveLeft();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
- Item 3
'''));
      });
      test('LEFT collapses an expanded node', () async {
        tree.select(tree.treeNodes[1]);
        tree.selectedItem.expand();
        await shortDelay();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
  - Item 2.1
  - Item 2.2
  - Item 2.3
- Item 3
'''));

        tree.moveLeft();
        await shortDelay();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
- Item 3
'''));
      });
      test('LEFT moves to parent of a collapsed node', () async {
        tree.treeNodes[1].expand();
        await shortDelay();
        tree.select(tree.treeNodes[1].children[1]);
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
  - Item 2.1
  - Item 2.2 ***
  - Item 2.3
- Item 3
'''));

        tree.moveLeft();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
  - Item 2.1
  - Item 2.2
  - Item 2.3
- Item 3
'''));
      });
      test('RIGHT does nothing for leaf node', () async {
        // Expand all the middle nodes to the leaf.
        var children = tree.treeNodes;
        while (children[1].hasChildren) {
          children[1].expand();
          await shortDelay();
          children = children[1].children;
          tree.select(children[1]);
        }

        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
  - Item 2.1
  - Item 2.2
    - Item 2.2.1
    - Item 2.2.2
      - Item 2.2.2.1
      - Item 2.2.2.2 ***
      - Item 2.2.2.3
    - Item 2.2.3
  - Item 2.3
- Item 3
'''));

        tree.moveRight();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
  - Item 2.1
  - Item 2.2
    - Item 2.2.1
    - Item 2.2.2
      - Item 2.2.2.1
      - Item 2.2.2.2 ***
      - Item 2.2.2.3
    - Item 2.2.3
  - Item 2.3
- Item 3
'''));
      });
      test('RIGHT expands a collapsed node', () async {
        tree.select(tree.treeNodes[1]);
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
- Item 3
'''));

        tree.moveRight();
        await shortDelay();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
  - Item 2.1
  - Item 2.2
  - Item 2.3
- Item 3
'''));
      });
      test('RIGHT moves to first child of expanded node', () async {
        tree.select(tree.treeNodes[1]);
        tree.selectedItem.expand();
        await shortDelay();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2 ***
  - Item 2.1
  - Item 2.2
  - Item 2.3
- Item 3
'''));

        tree.moveRight();
        expect(tree.getTextTree(), equals('''
- Item 1
- Item 2
  - Item 2.1 ***
  - Item 2.2
  - Item 2.3
- Item 3
'''));
      });
    });
  });
}

class TestStringTreeView extends SelectableTree<String> {
  TestStringTreeView() {
    setChildProvider(new StringChildProvider());
    setItems(['Item 1', 'Item 2', 'Item 3']);
    setRenderer((String value) => li(c: 'list-item')..add(span(text: value)));
  }

  /// Creates a text representation of the tree for comparing in tests.
  /// Selected item is suffixed with '***'.
  String getTextTree() {
    final StringBuffer output = StringBuffer();

    void addLevel(
        int indent, List<TreeNode<SelectableTreeNodeItem<String>>> nodes) {
      for (var node in nodes) {
        output.writeln(
            '${' ' * indent * 2}- ${node.data.item} ${node == selectedItem ? '***' : ''}'
                .trimRight());
        addLevel(indent + 1, node.visibleChildren);
      }
    }

    addLevel(0, treeNodes);
    return output.toString();
  }
}

class StringChildProvider extends ChildProvider<String> {
  @override
  Future<List<String>> getChildren(String item) =>
      Future.value(['$item.1', '$item.2', '$item.3']);

  @override
  bool hasChildren(String item) =>
      item.length < 'Item 1.1.1.1'.length; // Only go to 4 levels
}
