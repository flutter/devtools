// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/new/retaining_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RetainingPath equality', () {
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
}
