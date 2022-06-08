import 'package:collection/collection.dart';
import 'package:sorted_list/sorted_list.dart';

typedef Path = List<int>;

// class _NodesByDistance {
//   _NodesByDistance(this.nodes) {
//     _list = SortedList<int>(
//         (a, b) => nodes[a]!.distance.compareTo(nodes[b]!.distance));
//   }
//
//   final Map<int, _Node> nodes;
//   late SortedList<int> _list;
//
//   void add(int node) => _list.add(node);
//
//   void update(int node) {
//     _list.remove(node);
//     _list.add(node);
//   }
//
//   int removeMin() {
//     final result = _list.first;
//     _list.remove(result);
//     return result;
//   }
//
//   bool get isNotEmpty => _list.isNotEmpty;
// }

class _NodesByDistance {
  _NodesByDistance(this.nodes);

  static const _infinite = 100000000000;
  final Map<int, _Node> nodes;
  final _buckets = <int, Set<int>>{};
  int _minDistance = _infinite;

  void add(int node) {
    final distance = nodes[node]!.distance;
    _buckets[distance] ??= {};
    _buckets[distance]!.add(node);

    if (distance < _minDistance) {
      _minDistance = distance;
    }
  }

  void update(int node, distance, int next) {
    final oldDistance = nodes[node]!.distance;
    // New distance should be better than old distance.
    assert(oldDistance > distance);

    _minDistance = distance;

    _buckets[oldDistance]!.remove(node);
    if (_buckets[oldDistance]!.isEmpty) _buckets.remove(oldDistance);
    _buckets[distance] ??= {};
    _buckets[distance]!.add(node);

    nodes[node] = _Node(next: next, distance: distance);
  }

  int removeMin() {
    assert(isNotEmpty);
    assert(_buckets[_minDistance]!.isNotEmpty);

    final result = _buckets[_minDistance]!.first;
    _buckets[_minDistance]!.remove(result);

    if (_buckets[_minDistance]!.isNotEmpty) {
      return result;
    }
    _buckets.remove(_minDistance);

    if (_buckets.isEmpty) {
      _minDistance = _infinite;
      return result;
    }

    while (_buckets[_minDistance] == null) _minDistance++;
    return result;
  }

  bool get isNotEmpty => _minDistance != null;
}

/// Based on https://www.geeksforgeeks.org/prims-minimum-spanning-tree-mst-greedy-algo-5/
/// Returns null is there is no roots.
Path? findPathFromRoot(Map<int, Set<int>> incomers, int destination) {
  final nodes = <int, _Node>{destination: _Node()};
  final done = <int>{};
  final notYet = _NodesByDistance(nodes)..add(destination);

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
    final index = notYet.removeMin();
    final node = nodes[index]!;
    final theIncomers = incomers[index] ?? {};

    // If we found a root, return result;
    if (theIncomers.isEmpty) return path(index);

    done.add(index);

    for (var incomer in theIncomers) {
      if (!nodes.containsKey(incomer)) {
        nodes[incomer] = _Node(distance: node.distance + 1, next: index);
        notYet.add(incomer);
        continue;
      }
      if (nodes[incomer]!.distance > node.distance + 1) {
        assert(!done.contains(incomer));
        notYet.update(incomer, node.distance + 1, index);
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
