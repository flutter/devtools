typedef Path = List<int>;

/// Returns null if there is no path.
Path? findPathFromRoot(Map<int, Set<int>> incomers, int destination) {
  if (incomers[destination]?.isEmpty ?? true) return [destination];
  final destinationNode = _Node(index: destination);
  final nodes = <int, _Node>{destination: destinationNode};

  var cut = <_Node>[destinationNode];
  while (true) {
    final nextCut = <_Node>[];
    for (var node in cut) {
      for (var i in incomers[node.index] ?? {}) {
        if (nodes.containsKey(i)) continue;
        nodes[i] = _Node(index: i, next: node);
        if (incomers[i]?.isEmpty ?? true) return _path(nodes[i]!, nodes);
        nextCut.add(nodes[i]!);
      }
    }
    if (nextCut.isEmpty) return null;
    cut = nextCut;
  }
}

Path? _path(_Node node, Map<int, _Node> nodes) {
  final result = [node.index];

  while (true) {
    final next = node.next;
    if (next == null) return result;
    result.add(next.index);
    node = next;
  }
}

class _Node {
  _Node({required this.index, this.next});

  int index;
  final _Node? next;
}
