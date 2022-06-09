import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/memory/panes/leaks/model.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/graph_analyzer.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/retaining_path.dart';
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

  test('Six thousand not gc-ed.', () async {
    final task = await _loadTaskFromFile(
        'test/memory/leaks/data/six_thousand_not_gced.json');
    final pathAnalyzer = RetainingPathExtractor(task.objects);
    for (var report in task.reports) {
      report.retainingPath = pathAnalyzer.getPath(report.theIdentityHashCode);
    }
  });
}

Future<RetainingPathExtractionTask> _loadTaskFromFile(
  String fileNameFromProjectRoot,
) async {
  final json = jsonDecode(
    await File(fileNameFromProjectRoot).readAsString(),
  );
  return RetainingPathExtractionTask.fromJson(json);
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
