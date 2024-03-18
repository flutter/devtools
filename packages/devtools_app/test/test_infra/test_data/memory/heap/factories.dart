// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/classes.dart';
import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:vm_service/vm_service.dart';

import 'heap_graph_fakes.dart';

Future<HeapData> testHeapData([HeapSnapshotGraphFake? graph]) async =>
    await HeapData.calculate(
      graph ?? HeapSnapshotGraphFake(),
      DateTime.now(),
    );

SingleClassData testClassData(
  HeapClassName className,
  List<int> indexes,
  HeapSnapshotGraph graph,
) {
  final result = SingleClassData(className: className);
  for (final index in indexes) {
    result.countInstance(
      graph,
      index: index,
      retainers: null,
      retainedSizes: null,
    );
  }
  return result;
}
