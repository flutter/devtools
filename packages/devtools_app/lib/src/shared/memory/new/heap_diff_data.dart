// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'classes.dart';
import 'heap_data.dart';

class HeapDiffData {
  HeapDiffData._();

  ClassDataList<DiffClassData>? classes;
}

HeapDiffData calculateHeapDiffData(
  HeapData before,
  HeapData after,
) {
  return HeapDiffData._();
}
