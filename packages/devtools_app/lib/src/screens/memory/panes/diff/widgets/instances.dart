// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart';
import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/primitives/instance_context_menu.dart';
import '../controller/sampler.dart';
import 'class_details/instances_menu.dart';

/// Right aligned table cell, shat shows number of instances.
///
/// If the row is selected and count of instances is positive, the table cell
/// includes a "more" icon button with a context menu for the instance set.
class InstanceTableCell extends StatelessWidget {
  InstanceTableCell(
    ObjectSet objects,
    HeapDataCallback heap,
    HeapClassName heapClass, {
    super.key,
    required bool isSelected,
    required this.gaContext,
    this.liveItemsEnabled = true,
  })  : _sampleObtainer = _shouldShowMenu(isSelected, objects)
            ? HeapClassSampler(objects, heap(), heapClass)
            : null,
        _count = objects.instanceCount;

  static bool _shouldShowMenu(bool isSelected, ObjectSet objects) =>
      isSelected && objects.instanceCount > 0;

  final HeapClassSampler? _sampleObtainer;

  final MemoryAreas gaContext;
  final int _count;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    return InstanceViewWithContextMenu(
      count: _count,
      gaContext: gaContext,
      menuBuilder: () => buildHeapInstancesMenu(
        sampler: _sampleObtainer,
        liveItemsEnabled: liveItemsEnabled,
      ),
    );
  }
}
