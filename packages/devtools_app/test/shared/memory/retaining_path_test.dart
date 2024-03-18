// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:devtools_app/src/shared/memory/retaining_path.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/memory/heap/heap_graph_fakes.dart';

void main() {
  test('$PathFromRoot equality', () {
    final path1 = PathFromRoot.fromPath([
      HeapClassName.fromPath(library: 'Class1', className: 'lib'),
      HeapClassName.fromPath(library: 'Class2', className: 'lib'),
    ]);
    final path2 = PathFromRoot.fromPath([
      HeapClassName.fromPath(library: 'Class1', className: 'lib'),
      HeapClassName.fromPath(library: 'Class2', className: 'lib'),
    ]);
    final path3 = PathFromRoot.fromPath([
      HeapClassName.fromPath(library: 'Class1', className: 'lib'),
      HeapClassName.fromPath(library: 'Class2', className: 'lib_modified'),
    ]);

    expect(path1, path2);
    expect(path1, isNot(path3));
  });

  test('$PathFromRoot construction', () async {
    final root = HeapClassName.fromPath(className: 'Root', library: 'l');
    final classA = HeapClassName.fromPath(className: 'A', library: 'l');

    final graph = HeapSnapshotGraphFake()
      ..setObjects(
        {
          1: [2],
          2: [3],
          3: [4],
          4: [],
        },
        classes: {
          1: root,
          2: classA,
          3: classA,
          4: classA,
        },
      );

    final path = PathFromRoot.forObject(
      graph,
      shortestRetainers: const [0, 0, 1, 2, 3],
      index: 3,
    );

    expect(path.path, hasLength(1));
    expect(path.path[0], classA);
  });
}
