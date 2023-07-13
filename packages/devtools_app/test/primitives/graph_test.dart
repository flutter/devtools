// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/primitives/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GraphNode testNodeA;
  late GraphNode testNodeB;
  late GraphNode testNodeC;
  late GraphNode testNodeD;
  late GraphNode testNodeE;
  late GraphNode testNodeF;

  group('GraphNode', () {
    setUp(() {
      testNodeA = GraphNode();
      testNodeB = GraphNode();
      testNodeC = GraphNode();
      testNodeD = GraphNode();
      testNodeE = GraphNode();
      testNodeF = GraphNode();
      testNodeA
        ..outgoingEdge(testNodeB)
        ..outgoingEdge(testNodeC)
        ..outgoingEdge(testNodeD);
      testNodeB
        ..outgoingEdge(testNodeC)
        ..outgoingEdge(testNodeD);
      testNodeD
        ..outgoingEdge(testNodeE)
        ..outgoingEdge(testNodeF);
      testNodeF.outgoingEdge(testNodeB);

      // Extra edges to make the edge counts interesting.
      testNodeA
        ..outgoingEdge(testNodeB)
        ..outgoingEdge(testNodeC)
        ..outgoingEdge(testNodeC);

      testNodeB.outgoingEdge(testNodeC);

      testNodeD
        ..outgoingEdge(testNodeE)
        ..outgoingEdge(testNodeE);
    });

    test('predecessor and successor lists are accurate', () {
      expect(testNodeA.predecessors, isEmpty);
      expect(testNodeA.successors, {testNodeB, testNodeC, testNodeD});

      expect(testNodeB.predecessors, {testNodeA, testNodeF});
      expect(testNodeB.successors, {testNodeC, testNodeD});

      expect(testNodeC.predecessors, {testNodeA, testNodeB});
      expect(testNodeC.successors, isEmpty);

      expect(testNodeD.predecessors, {testNodeA, testNodeB});
      expect(testNodeD.successors, {testNodeE, testNodeF});

      expect(testNodeE.predecessors, {testNodeD});
      expect(testNodeE.successors, isEmpty);

      expect(testNodeF.predecessors, {testNodeD});
      expect(testNodeF.successors, {testNodeB});
    });

    test('predecessor and successor edge counts are accurate', () {
      expect(testNodeA.predecessorEdgeCounts.keys, isEmpty);
      expect(testNodeA.predecessorEdgeCounts.values, isEmpty);
      expect(
        testNodeA.successorEdgeCounts.keys,
        [testNodeB, testNodeC, testNodeD],
      );
      expect(testNodeA.successorEdgeCounts.values, [2, 3, 1]);

      expect(testNodeB.predecessorEdgeCounts.keys, [testNodeA, testNodeF]);
      expect(testNodeB.predecessorEdgeCounts.values, [2, 1]);
      expect(testNodeB.successorEdgeCounts.keys, [testNodeC, testNodeD]);
      expect(testNodeB.successorEdgeCounts.values, [2, 1]);

      expect(testNodeC.predecessorEdgeCounts.keys, [testNodeA, testNodeB]);
      expect(testNodeC.predecessorEdgeCounts.values, [3, 2]);
      expect(testNodeC.successorEdgeCounts.keys, isEmpty);
      expect(testNodeC.successorEdgeCounts.values, isEmpty);

      expect(testNodeD.predecessorEdgeCounts.keys, [testNodeA, testNodeB]);
      expect(testNodeD.predecessorEdgeCounts.values, [1, 1]);
      expect(testNodeD.successorEdgeCounts.keys, [testNodeE, testNodeF]);
      expect(testNodeD.successorEdgeCounts.values, [3, 1]);

      expect(testNodeE.predecessorEdgeCounts.keys, [testNodeD]);
      expect(testNodeE.predecessorEdgeCounts.values, [3]);
      expect(testNodeE.successorEdgeCounts.keys, isEmpty);
      expect(testNodeE.successorEdgeCounts.values, isEmpty);

      expect(testNodeF.predecessorEdgeCounts.keys, [testNodeD]);
      expect(testNodeF.predecessorEdgeCounts.values, [1]);
      expect(testNodeF.successorEdgeCounts.keys, [testNodeB]);
      expect(testNodeF.successorEdgeCounts.values, [1]);
    });
  });
}
