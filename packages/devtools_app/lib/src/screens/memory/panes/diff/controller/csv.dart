// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import '../../../shared/heap/heap.dart';
import 'heap_diff.dart';

String classesToCsv(HeapClasses classes) {
  if (classes is SingleHeapClasses) return _singleClassesToCsv(classes);
  if (classes is DiffHeapClasses) return _diffClassesToCsv(classes);
  throw StateError('Unexpected type: ${classes.runtimeType}');
}

String _singleClassesToCsv(SingleHeapClasses classes) {
  final csvBuffer = StringBuffer();

  // Write the headers first.
  csvBuffer.writeln(
    [
      'Class',
      'Library',
      'Instances',
      'Shallow Dart Size',
      'Retained Dart Size',
      'Short Retaining Path',
      'Full Retaining Path',
    ].map((e) => '"$e"').join(','),
  );

  for (var classStats in classes.classes) {
    for (var pathStats in classStats.entries) {
      csvBuffer.writeln(
        [
          classStats.heapClass.className,
          classStats.heapClass.library,
          pathStats.value.instanceCount,
          pathStats.value.shallowSize,
          pathStats.value.retainedSize,
          pathStats.key.asShortString(),
          pathStats.key.asLongString(delimiter: ' | '),
        ].join(','),
      );
    }
  }

  return csvBuffer.toString();
}

String _diffClassesToCsv(DiffHeapClasses classes) {
  return '';
}
