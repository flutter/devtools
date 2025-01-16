// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$RemoteDiagnosticsNode', () {
    group('equality', () {
      test('equality is order agnostic', () {
        final json1 = <String, dynamic>{
          'a': 1,
          'b': <String, dynamic>{'x': 2, 'y': 3},
        };
        final json2 = <String, dynamic>{
          'b': <String, dynamic>{'y': 3, 'x': 2},
          'a': 1,
        };
        expect(
          RemoteDiagnosticsNode.jsonHashCode(json1),
          RemoteDiagnosticsNode.jsonHashCode(json2),
        );
        expect(RemoteDiagnosticsNode.jsonEquality(json1, json2), isTrue);
      });

      test('equality is deep', () {
        final json1 = <String, dynamic>{
          'a': 1,
          'b': <String, dynamic>{'x': 3, 'y': 2},
        };
        final json2 = <String, dynamic>{
          'b': <String, dynamic>{'y': 3, 'x': 2},
          'a': 1,
        };
        expect(RemoteDiagnosticsNode.jsonEquality(json1, json2), isFalse);
      });
    });

    group('hidden groups', () {
      final implementationNodeWithNoChildren = buildImplementationNodeJson(
        description: 'ImplementationNodeWithNoChildren',
        children: [],
      );

      final implementationNodeWithSingleChild = buildImplementationNodeJson(
        description: 'ImplementationNodeWithSingleChild',
        children: [implementationNodeWithNoChildren],
      );

      final implementationNodeWithMultipleChildren =
          buildImplementationNodeJson(
            description: 'ImplementationNodeWithMultipleChildren',
            children: [
              implementationNodeWithNoChildren,
              implementationNodeWithSingleChild,
            ],
          );

      final projectNodeWithSingleChild = buildProjectNodeJson(
        description: 'ProjectNodeWithSingleChild',
        children: [implementationNodeWithSingleChild],
      );

      RemoteDiagnosticsNode buildHideableNode() {
        // Build the parent for the node (to be hideable, a node must be the
        // only child of its parent):
        final parent = buildNode(implementationNodeWithSingleChild);
        // Build the node as an implementation node (to be hideable, a node must
        // be an implementation node):
        final node = buildNode(
          implementationNodeWithSingleChild,
          parent: parent,
        );
        // Build a child for the node (to be hideable, a node must have at most
        // one child):
        buildNode(implementationNodeWithNoChildren, parent: node);

        return node;
      }

      RemoteDiagnosticsNode buildHideableGroupLeaderWithNSubordinates(int n) {
        final leader = buildHideableNode();
        for (var i = 1; i <= n; i++) {
          leader.addHideableGroupSubordinate(buildHideableNode());
        }

        return leader;
      }

      group('hidden group determination', () {
        test('if node was created by the local project, it is not hideable', () {
          // Build the parent for the node (to be hideable, a node must be the
          // only child of its parent):
          final parent = buildNode(implementationNodeWithSingleChild);
          // Build the node as a project node (project nodes are NOT hideable):
          final node = buildNode(projectNodeWithSingleChild, parent: parent);
          // Build a child for the node (to be hideable, a node must have at most
          // one child):
          buildNode(projectNodeWithSingleChild, parent: node);

          expect(node.inHideableGroup, isFalse);
        });

        test('if a node has any siblings, it is not hideable', () {
          // Build the parent for the node (nodes with siblings are NOT hideable):
          final parent = buildNode(implementationNodeWithMultipleChildren);
          // Build the node as an implementation node (to be hideable, a node must
          // be an implementation node):
          final node = buildNode(
            implementationNodeWithSingleChild,
            parent: parent,
          );
          // Build a child for the node (to be hideable, a node must have at most
          // one child):
          buildNode(implementationNodeWithNoChildren, parent: node);
          // Build a sibling for the node (nodes with siblings are NOT hideable):
          buildNode(implementationNodeWithNoChildren, parent: parent);

          expect(node.inHideableGroup, isFalse);
        });

        test('if node has multiple children, it is not hideable', () {
          // Build the parent for the node (to be hideable, a node must be the
          // only child of its parent):
          final parent = buildNode(implementationNodeWithSingleChild);
          // Build the node as an implementation node (to be hideable, a node must
          // be an implementation node):
          final node = buildNode(
            implementationNodeWithMultipleChildren,
            parent: parent,
          );
          // Build multiple children for the node (nodes with multiple children
          // are NOT hideable):
          buildNode(implementationNodeWithNoChildren, parent: node);
          buildNode(implementationNodeWithNoChildren, parent: node);

          expect(node.inHideableGroup, isFalse);
        });

        test(
          'if node\'s parent and child are both not hideable, it is not hideable',
          () {
            // Build the child as a project node (project nodes are NOT
            // hideable):
            final childJson = buildProjectNodeJson(children: []);
            // Build the node as an implementation node (to be hideable, a node must
            // be an implementation node):
            final nodeJson = buildImplementationNodeJson(children: [childJson]);
            // Build the parent as a project node (project nodes are NOT
            // hideable):
            final parentJson = buildProjectNodeJson(children: [nodeJson]);
            final parent = buildNode(parentJson);
            final node = buildNode(nodeJson, parent: parent);
            final child = buildNode(childJson, parent: node);

            expect(parent.inHideableGroup, isFalse);
            expect(child.inHideableGroup, isFalse);
            expect(node.inHideableGroup, isFalse);
          },
        );

        test(
          'if node\'s parent is not hideable and it has no children, it is not hideable',
          () {
            // Build the node as an implementation node (to be hideable, a node must
            // be an implementation node):
            final nodeJson = buildImplementationNodeJson(children: []);
            // Build the parent as a project node (project nodes are NOT
            // hideable):
            final parentJson = buildProjectNodeJson(children: [nodeJson]);
            final parent = buildNode(parentJson);
            final node = buildNode(nodeJson, parent: parent);

            expect(parent.inHideableGroup, isFalse);
            expect(node.hasChildren, isFalse);
            expect(node.inHideableGroup, isFalse);
          },
        );

        test('otherwise, node is hideable', () {
          final node = buildHideableNode();
          expect(node.inHideableGroup, isTrue);
        });
      });

      group('hidden group manipulation', () {
        test('hideable node with subordinates is the group leader', () {
          final node = buildHideableNode();
          expect(node.isHideableGroupLeader, isFalse);

          node
            ..addHideableGroupSubordinate(buildHideableNode())
            ..addHideableGroupSubordinate(buildHideableNode());
          expect(node.isHideableGroupLeader, isTrue);
        });

        test('hideableGroupSubordinates returns the subordinates', () {
          final node = buildHideableGroupLeaderWithNSubordinates(3);

          expect(node.hideableGroupSubordinates, hasLength(3));
        });

        test('hideable group leader is never hidden', () {
          final node = buildHideableGroupLeaderWithNSubordinates(2);

          expect(node.isHidden, isFalse);
          node.toggleHiddenGroup();
          expect(node.isHidden, isFalse);
        });

        test('hideable group subordinates start out hidden', () {
          final node = buildHideableGroupLeaderWithNSubordinates(2);

          expect(node.hideableGroupSubordinates![0].isHidden, isTrue);
          expect(node.hideableGroupSubordinates![1].isHidden, isTrue);
          node.toggleHiddenGroup();
          expect(node.hideableGroupSubordinates![0].isHidden, isFalse);
          expect(node.hideableGroupSubordinates![1].isHidden, isFalse);
        });

        test('subordinates cannot change hideable state', () {
          final node = buildHideableGroupLeaderWithNSubordinates(2);

          expect(() {
            node.hideableGroupSubordinates![0].toggleHiddenGroup();
          }, throwsAssertionError);
        });

        test('hideable group subordinates have correct leader', () {
          final node = buildHideableGroupLeaderWithNSubordinates(2);

          expect(
            node.hideableGroupSubordinates![0].hideableGroupLeader,
            equals(node),
          );
          expect(
            node.hideableGroupSubordinates![1].hideableGroupLeader,
            equals(node),
          );
        });

        test('hideable group leader of leader is itself', () {
          final node = buildHideableGroupLeaderWithNSubordinates(2);

          expect(node.hideableGroupLeader, equals(node));
        });
      });
    });
  });
}

Map<String, dynamic> buildImplementationNodeJson({
  required List<Map<String, dynamic>> children,
  String? description,
}) => buildNodeJson(
  description: description ?? 'ImplementationNode',
  createdByLocalProject: false,
  children: children,
);

Map<String, dynamic> buildProjectNodeJson({
  required List<Map<String, dynamic>> children,
  String? description,
}) => buildNodeJson(
  description: description ?? 'ProjectNode',
  createdByLocalProject: true,
  children: children,
);

Map<String, dynamic> buildNodeJson({
  required String description,
  required bool createdByLocalProject,
  required List<Map<String, dynamic>> children,
}) => <String, dynamic>{
  'description': description,
  'createdByLocalProject': createdByLocalProject,
  'hasChildren': children.isNotEmpty,
  'children': children,
};
RemoteDiagnosticsNode buildNode(
  Map<String, dynamic> nodeJson, {
  RemoteDiagnosticsNode? parent,
}) => RemoteDiagnosticsNode(
  nodeJson,
  MockInspectorObjectGroupBase(),
  false,
  parent,
);
