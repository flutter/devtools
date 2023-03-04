// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../shared/primitives/simple_elements.dart';

class RetainingPathController {
  final hideStandard = ValueNotifier<bool>(true);
  final invert = ValueNotifier<bool>(true);
}

class ClassesTableSingleController {
  ClassesTableSingleController({
    required this.heap,
    required this.totalHeapSize,
    required this.filterButton,
  });

  // We use functions, not [ValueListener], because we do not want widgets
  // to subscribe for the changes, for performance reasons.

  final HeapDataObtainer heap;
  final int Function() totalHeapSize;
  final Widget Function() filterButton;
}

class ClassesTableDiffController {
  ClassesTableDiffController({
    required this.before,
    required this.after,
    required this.filterButton,
    required this.selectedSizeType,
  });

  // We use functions, not [ValueListener], because we do not want widgets
  // to subscribe for the changes, for performance reasons.

  final HeapDataObtainer before;
  final HeapDataObtainer after;
  final Widget Function() filterButton;
  final ValueNotifier<SizeType> selectedSizeType;
}
