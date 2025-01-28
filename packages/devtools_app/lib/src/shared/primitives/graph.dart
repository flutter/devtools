// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';

/// A dart object that represents a graph.
///
/// Each [GraphNode] has a set of [predecessors] and [successors], which
/// represent incoming and outgoing edges, respectively. A [GraphNode] in
/// [predecessors] or [successors] may have multiple edges to this [GraphNode].
///
/// For each predecessor [GraphNode] in [predecessors], the edge count to this
/// [GraphNode] from the predecessor is stored in [predecessorEdgeCounts].
///
/// For each successor [GraphNode] in [successors], the edge count from this
/// [GraphNode] to the successor is stored in [successorEdgeCounts].
class GraphNode {
  /// Predecessors of this node.
  final predecessors = <GraphNode>{};

  /// Successors of this node.
  final successors = <GraphNode>{};

  /// Maps predecessor [GraphNode]s from [predecessors] to the number of
  /// outgoing edges going to [this] node.
  ///
  /// For example:
  ///        A (predecessor node)
  ///      /  \
  ///     |    |
  ///      \  /
  ///       B (this node)
  ///
  /// ==> successorEdgeCounts[A] = 2
  final predecessorEdgeCounts = <GraphNode, int>{};

  /// Maps successor [GraphNode]s from [successors] to the number of incoming
  /// edges coming from [this] node.
  ///
  /// For example:
  ///        A (this node)
  ///      /  \
  ///     |    |
  ///      \  /
  ///       B (successor node)
  ///
  /// ==> successorEdgeCounts[B] = 2
  final successorEdgeCounts = <GraphNode, int>{};

  /// Returns the percentage of this node's predecessor edges that connect to
  /// [node].
  double predecessorEdgePercentage(GraphNode node) {
    if (predecessorEdgeCounts.keys.contains(node)) {
      final totalEdgeCount = predecessorEdgeCounts.values.sum;
      return predecessorEdgeCounts[node]! / totalEdgeCount;
    }
    return 0.0;
  }

  /// Returns the percentage of this node's sucessor edges that connect to
  /// [node].
  double successorEdgePercentage(GraphNode node) {
    if (successorEdgeCounts.keys.contains(node)) {
      final totalEdgeCount = successorEdgeCounts.values.sum;
      return successorEdgeCounts[node]! / totalEdgeCount;
    }
    return 0.0;
  }

  /// Create outgoing edge from [this] node to the given node [n].
  void outgoingEdge(GraphNode n, {int edgeWeight = 1}) {
    n.predecessors.add(this);
    final predEdgeCount = n.predecessorEdgeCounts[this] ?? 0;
    n.predecessorEdgeCounts[this] = predEdgeCount + edgeWeight;

    successors.add(n);
    final succEdgeCount = successorEdgeCounts[n] ?? 0;
    successorEdgeCounts[n] = succEdgeCount + edgeWeight;
  }
}
