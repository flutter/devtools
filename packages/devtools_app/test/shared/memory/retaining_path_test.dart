// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
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

  group('$PathFromRoot construction', () {
    final root = HeapClassName.fromPath(className: 'Root', library: 'l');
    final classA = HeapClassName.fromPath(className: 'A', library: 'l');
    final classB = HeapClassName.fromPath(className: 'B', library: 'l');
    final classC = HeapClassName.fromPath(className: 'C', library: 'l');

    final graph = FakeHeapSnapshotGraph()
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
          3: classB,
          4: classC,
        },
      );
    const shortestRetainers = [0, 0, 1, 2, 3];

    PathFromRoot objectPath(int index) => PathFromRoot.forObject(
          graph,
          shortestRetainers: shortestRetainers,
          index: index,
        );

    test('directly to root', () {
      final path = objectPath(2);

      expect(path.path, hasLength(0));
    });

    test('one step', () {
      final path = objectPath(3);

      expect(path.path, hasLength(1));
      expect(path.path[0], classA);
    });

    test('two steps', () {
      final path = objectPath(4);

      expect(path.path, hasLength(2));
      expect(path.path[0], classB);
      expect(path.path[1], classA);
    });
  });
}
