import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/memory/panes/leaks/leak_analyser.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/model.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/retaining_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_tools/model.dart';

void main() {
  group('Thousands', () {
    late RetainingPathExtractionTask task;
    late RetainingPathExtractor pathExtractor;

    setUp(() async {
      task = await _loadTaskFromFile(
        'test/memory/leaks/data/thousands_not_gced_task.json',
      );
      pathExtractor = RetainingPathExtractor(task.objects);
    });

    test('has many roots.', () async {
      final roots = pathExtractor.getRoots();
      expect(roots, hasLength(337823));
    });

    test('has many objects.', () async {
      expect(task.objects, hasLength(530945));
    });

    test('has path to gallery.', () async {
      final galleryAppCode = pathExtractor.objects.keys
          .firstWhere((k) => pathExtractor.objects[k]!.klass == 'GalleryApp');
      final path = pathExtractor.getPath(galleryAppCode);
      assert(path!.contains('GalleryApp'));
    });

    test('finds path for an object.', () async {
      const objectWithPath = 681924862;
      final extractor = RetainingPathExtractor(task.objects);
      final report = task.reports
          .firstWhere((r) => r.theIdentityHashCode == objectWithPath);
      setRetainingPathsOrRetainers(extractor, report);
      expect(report.retainingPath, isNotNull);
      expect(report.retainers, isNull);
    });

    test('has some paths for not gced', () async {
      calculateRetainingPathsOrRetainers(task);

      var pathCount = 0;
      for (var report in task.reports) {
        if (report.retainingPath != null) pathCount++;
      }

      expect(task.reports.length, 3076);
      expect(pathCount, 2249);
    });

    test('has expected result', () async {
      calculateRetainingPathsOrRetainers(task);
      final result = analyzeAndYaml(Leaks({LeakType.notGCed: task.reports}));
      await File(
        'test/memory/leaks/data/thousands_not_gced_result.yaml',
      ).writeAsString(result);
    });
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
