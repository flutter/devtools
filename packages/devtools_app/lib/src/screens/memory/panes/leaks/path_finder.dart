import 'package:collection/collection.dart';

typedef Path = List<int>;

/// Based on https://www.geeksforgeeks.org/prims-minimum-spanning-tree-mst-greedy-algo-5/
/// Returns null is there is no roots.
Path? findPathFromRoot(Map<int, Set<int>> incomers, int destination) {
  final nodes = <int, _Node>{destination: _Node()};
  final done = <int>{};
  final notYet = <int>{destination};

  int minDistance(Iterable<int> set) => set.reduce(
        (current, next) =>
            nodes[current]!.distance < nodes[next]!.distance ? current : next,
      );

  List<int> path(int index) {
    final result = [index];

    while (true) {
      final next = nodes[index]!.next;
      if (next == null) return result;
      index = next;
      result.add(index);
    }
  }

  while (notYet.isNotEmpty) {
    final index = minDistance(notYet);
    final node = nodes[index]!;
    final theIncomers = incomers[index] ?? {};

    // If we found a root, return result;
    if (theIncomers.isEmpty) return path(index);

    // Move the node from [notYet] to [done].
    done.add(index);
    notYet.remove(index);

    for (var incomer in theIncomers) {
      if (!nodes.containsKey(incomer)) {
        nodes[incomer] = _Node(distance: node.distance + 1, next: index);
        notYet.add(incomer);
        continue;
      }
      if (nodes[incomer]!.distance > node.distance + 1) {
        assert(!done.contains(incomer));
        nodes[incomer] = _Node(distance: node.distance + 1, next: index);
      }
    }
  }

  return null;
}

class _Node {
  _Node({this.next, this.distance = 0});

  final int distance;
  final int? next;
}
