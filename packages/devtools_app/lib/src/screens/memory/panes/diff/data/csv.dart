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

  for (final classData in classes) {
    for (final pathStats in classData.byPath.entries) {
      csvBuffer.writeln(
        [
          classData.className.className,
          classData.className.library,
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
