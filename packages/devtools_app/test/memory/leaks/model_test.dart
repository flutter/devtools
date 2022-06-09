import 'dart:convert';

import 'package:devtools_app/src/screens/memory/panes/leaks/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_tools/model.dart';

void main() {
  test('LeakAnalysisTask serializes.', () {
    final task = RetainingPathExtractionTask(
      objects: {
        1: HeapObject(klass: 'class', references: [2, 3, 4])
      },
      reports: [
        ObjectReport(
          token: '1',
          type: 'type',
          creationLocation: 'location',
          theIdentityHashCode: 2,
        )
      ],
    );

    final json = task.toJson();

    expect(
      jsonEncode(json),
      jsonEncode(RetainingPathExtractionTask.fromJson(json).toJson()),
    );
  });
}
