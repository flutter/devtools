// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/new/classes.dart';
import '../../../shared/heap/class_filter.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/primitives/simple_elements.dart';
import 'heap_diff_.dart';

class RetainingPathController {
  final hideStandard = ValueNotifier<bool>(true);
  final invert = ValueNotifier<bool>(true);
}

class ClassesTableSingleData {
  ClassesTableSingleData({
    required this.heap,
    required this.totalHeapSize,
    required this.filterData,
  });

  // We use functions, not [ValueListenable], where we do not want widgets
  // to subscribe for the changes, for performance reasons.

  /// Function to get currently selected heap.
  final HeapDataCallback heap;

  /// Function to get total currently selected heap size.
  final int Function() totalHeapSize;

  /// Current class filter data.
  final ClassFilterData filterData;

  /// Selected class.
  final selection = ValueNotifier<SingleClassData?>(null);
}

class ClassesTableDiffData {
  ClassesTableDiffData({
    required this.before,
    required this.after,
    required this.filterData,
  });

  /// Size type to show.
  final selectedSizeType = ValueNotifier<SizeType>(SizeType.retained);

  // We use functions, not [ValueListenable], where we do not want widgets
  // to subscribe for the changes, for performance reasons.

  /// Function to get selected first heap to diff.
  final HeapDataCallback_ before;

  /// Function to get selected second heap to diff.
  final HeapDataCallback_ after;

  /// Current class filter data.
  final ClassFilterData filterData;

  /// Selected class.
  final selection = ValueNotifier<DiffClassStats?>(null);
}
