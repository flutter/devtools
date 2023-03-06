// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../shared/heap/class_filter.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/primitives/simple_elements.dart';
import 'heap_diff.dart';

class RetainingPathController {
  final hideStandard = ValueNotifier<bool>(true);
  final invert = ValueNotifier<bool>(true);
}

class ClassFilterController {
  ClassFilterController({
    required this.filter,
    required this.onChanged,
    required this.rootPackage,
  });

  final ValueListenable<ClassFilter> filter;
  final Function(ClassFilter) onChanged;
  final String? rootPackage;
}

class ClassesTableSingleController {
  ClassesTableSingleController({
    required this.selection,
    required this.heap,
    required this.totalHeapSize,
    required this.filterController,
  });

  // We use functions, not [ValueListener], where we do not want widgets
  // to subscribe for the changes, for performance reasons.

  final HeapDataObtainer heap;
  final int Function() totalHeapSize;
  final ClassFilterController filterController;
  final ValueNotifier<SingleClassStats?> selection;
}

class ClassesTableDiffController {
  ClassesTableDiffController({
    required this.selection,
    required this.before,
    required this.after,
    required this.filterController,
  });

  final selectedSizeType = ValueNotifier<SizeType>(SizeType.retained);

  // We use functions, not [ValueListener], where we do not want widgets
  // to subscribe for the changes, for performance reasons.

  final HeapDataObtainer before;
  final HeapDataObtainer after;
  final ClassFilterController filterController;
  final ValueNotifier<DiffClassStats?> selection;
}
