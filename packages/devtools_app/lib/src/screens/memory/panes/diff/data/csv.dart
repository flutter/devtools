// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../../shared/memory/classes.dart';

String classesToCsv(Iterable<ClassData> classes) {
  final csvBuffer = StringBuffer();

  // Write the headers first.
  csvBuffer.writeln(
    [
      'Class',
      'Library',
      'Instances',
      'Shallow',
      'Retained',
      'Short Retaining Path',
      'Full Retaining Path',
    ].map((e) => '"$e"').join(','),
  );

  for (var classData in classes) {
    for (var pathStats in classData.byPath.entries) {
      csvBuffer.writeln(
        [
          classData.heapClass.className,
          classData.heapClass.library,
          pathStats.value.instanceCount,
          pathStats.value.shallowSize,
          pathStats.value.retainedSize,
          pathStats.key.toShortString(),
          pathStats.key.toLongString(delimiter: ' | '),
        ].join(','),
      );
    }
  }

  return csvBuffer.toString();
}
