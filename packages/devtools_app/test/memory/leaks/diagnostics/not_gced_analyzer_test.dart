import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/heap_analyser.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/not_gced_analyzer.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/formatter.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/instrumentation/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dataDir = 'test/memory/leaks/diagnostics/not_gced_analyzer_test/';

  final tests = [
    _Test(
      name: 'leaking_demo_app',
      appClassName: 'MyApp',
    ),
  ];

  for (var t in tests) {
    group(t.name, () {
      late NotGCedAnalyzerTask task;

      setUp(() async {
        task = await _loadTaskFromFile('$dataDir${t.name}.raw.json');
      });

      test('There are many objects and roots.', () {
        expect(task.heap.objects.length, greaterThan(1000));
        expect(
          task.heap.objects[AdaptedHeap.rootIndex].references.length,
          greaterThan(1000),
          reason: t.name,
        );
      });

      test('There is exactly one object of type ${t.appClassName}.', () {
        final appObjects =
            task.heap.objects.where((o) => o.klass == t.appClassName);
        expect(appObjects, hasLength(1), reason: t.name);
      });

      test('There is path to the object of type ${t.appClassName}.', () async {
        buildSpanningTree(task.heap);
        final appObject =
            task.heap.objects.where((o) => o.klass == t.appClassName).first;
        expect(appObject.retainer, isNotNull, reason: t.name);
      });

      // This test does not verify results, because the code is not stable yet.
      // We need the test to make sure (1) the code does not fail and (2)
      // to see the changes in the output file in code reviews.
      test('Write result to file.', () async {
        final result = analyseNotGCed(task);

        final yaml = analyzedLeaksToYaml(
          gcedLate: [],
          notDisposed: [],
          notGCed: result,
        );

        await File(
          '$dataDir${t.name}.yaml',
        ).writeAsString(yaml);
      });
    });
  }

  test('Culprits are found as expected.', () {
    final culprit1 = _createReport(1, '/1/2/');
    final culprit2 = _createReport(2, '/1/7/');

    final notGCed = [
      culprit1,
      _createReport(11, '/1/2/3/4/5/'),
      _createReport(12, '/1/2/3/'),
      culprit2,
      _createReport(21, '/1/7/3/4/5/'),
      _createReport(22, '/1/7/3/'),
    ];

    final culprits = findCulprits(notGCed);

    expect(culprits, hasLength(2));
    expect(culprits.keys, contains(culprit1));
    expect(culprits[culprit1], hasLength(2));
    expect(culprits.keys, contains(culprit2));
    expect(culprits[culprit2], hasLength(2));
  });
}

LeakReport _createReport(int code, String path) => LeakReport(
      type: '',
      details: ['details'],
      code: 0,
      disposalStack: 'disposalStack\ndisposalStack',
    )..retainingPath = path;

class _Test {
  _Test({
    required this.name,
    required this.appClassName,
  });

  final String name;
  final String appClassName;
}

Future<NotGCedAnalyzerTask> _loadTaskFromFile(
  String fileNameFromProjectRoot,
) async {
  final json = jsonDecode(
    await File(fileNameFromProjectRoot).readAsString(),
  );
  return NotGCedAnalyzerTask.fromJson(json);
}
