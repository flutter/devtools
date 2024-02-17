// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/new/retaining_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RetainingPath equality', () {
    final path1 = RetainingPath.fromPath([
      HeapClassName.fromPath(library: 'Class', className: 'lib'),
      HeapClassName.fromPath(library: 'Class', className: 'lib'),
    ]);
    final path2 = RetainingPath.fromPath([
      HeapClassName.fromPath(library: 'Class', className: 'lib'),
      HeapClassName.fromPath(library: 'Class', className: 'lib'),
    ]);
    final path3 = RetainingPath.fromPath([
      HeapClassName.fromPath(library: 'Class', className: 'lib'),
      HeapClassName.fromPath(library: 'Class', className: 'lib_modified'),
    ]);

    expect(path1, path2);
    expect(path1, isNot(path3));
  });
}
