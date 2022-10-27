// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../../shared/globals.dart';
import '../../../shared/heap/heap.dart';

class TimeWatcher {
  DateTime start = DateTime.now();
  void tap(Object o) {
    final t = DateTime.now();
    print('$o: ${t.difference(start)}');
    start = t;
  }
}

String classesToCsv(Iterable<ClassStats> classes) {
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

  for (var classStats in classes) {
    for (var pathStats in classStats.statsByPathEntries) {
      csvBuffer.writeln(
        [
          classStats.heapClass.className,
          classStats.heapClass.library,
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

/// Returns root package or empty string.
Future<String?> tryToDetectRootPackage() async {
  final rootLib = await serviceManager.tryToDetectMainRootLib();
  if (rootLib == null) return null;
  final slashIndex = rootLib.indexOf('/');
  if (slashIndex == -1) return null;
  return rootLib.substring(0, slashIndex);
}
