typedef Path = List<int>;

/// Returns null if there is no path to root.
Path? findPathFromRoot(Map<int, Set<int>> incomers, int destination) {
  bool isRoot(int index) => incomers[index]?.isEmpty ?? true;
  if (isRoot(destination)) return [destination];

  // Array of all nodes where the best distance to destination is n.
  // n starts with 0 and increases by 1 on each step of the algorithm.
  var cut = [_Node(index: destination)];
  // Set of node indexes, where shortest distance is already calculated and it is
  // not worth than the distance in the current [cut].
  final calculated = {destination};

  // On each step of algorithm we know that there is no roots closer
  // than nodes in the current cut, to the destination.
  while (true) {
    final nextCut = <_Node>[];
    for (var node in cut) {
      for (var i in incomers[node.index] ?? {}) {
        if (calculated.contains(i)) continue;
        final newNode = _Node(index: i, next: node);
        if (isRoot(i)) return _path(newNode);
        nextCut.add(newNode);
        calculated.add(i);
      }
    }
    if (nextCut.isEmpty) return null;
    cut = nextCut;
  }
}

Path _path(_Node node) {
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
