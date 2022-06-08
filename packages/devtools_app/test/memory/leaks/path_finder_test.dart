import 'package:devtools_app/src/screens/memory/panes/leaks/path_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Trivial path.', () {
    final path = findPathFromRoot({}, 1);
    expect(path, equals([1]));
  });

  test('Trivial path with other nodes.', () {
    final path = findPathFromRoot(
      {
        2: {3}
      },
      1,
    );
    expect(path, equals([1]));
  });

  test('Trivial loop.', () {
    final path = findPathFromRoot(
      {
        1: {1},
      },
      1,
    );
    expect(path, equals(null));
  });

  test('Two node loop.', () {
    final path = findPathFromRoot(
      {
        2: {1},
        1: {2},
      },
      1,
    );
    expect(path, equals(null));
  });

  test('Two node path.', () {
    final path = findPathFromRoot(
      {
        2: {1},
      },
      2,
    );
    expect(path, equals([1, 2]));
  });

  test('Shortest path.', () {
    final path = findPathFromRoot(
      {
        3: {2, 1},
        2: {1},
      },
      3,
    );
    expect(path, equals([1, 3]));
  });

  test('Full graph.', () {
    const size = 10000;
    final incomers = _fullGraph(size);

    const root = size;
    const retainer = 0;
    const destination = size - 1;

    // Add root.
    incomers[retainer]!.add(root);
    final path = findPathFromRoot(incomers, destination);
    expect(path, equals([size, retainer, destination]));
  });
}

Map<int, Set<int>> _fullGraph(int size) {
  final result = <int, Set<int>>{};
  for (var i in Iterable.generate(size)) {
    final set = <int>{};
    result[i] = set;
    for (var j in Iterable.generate(size)) {
      if (i != j) set.add(j);
    }
  }
  return result;
}
