typedef Path = List<int>;

/// Returns null if there is no path to root.
Path? findPathFromRoot(Map<int, Set<int>> incomers, int destination) {
  bool isRoot(int index) => incomers[index]?.isEmpty ?? true;
  if (isRoot(destination)) return [destination];

  final visited = {destination};
  var cut = [_Node(index: destination)];

  while (true) {
    final nextCut = <_Node>[];
    for (var node in cut) {
      for (var i in incomers[node.index] ?? {}) {
        if (visited.contains(i)) continue;
        final newNode = _Node(index: i, next: node);
        if (isRoot(i)) return _path(newNode);
        visited.add(i);
        nextCut.add(newNode);
      }
    }
    if (nextCut.isEmpty) return null;
    cut = nextCut;
  }
}

Path? _path(_Node node) {
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
