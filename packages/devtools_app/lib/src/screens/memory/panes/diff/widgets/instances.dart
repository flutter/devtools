// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart';
import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/theme.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/primitives/instance_set_button.dart';
import '../controller/sampler.dart';

/// Right aligned table cell, shat shows number of instances.
///
/// If the row is selected and count of instances is positive, shows ellipsis button
/// with context menu for the instance set.
class InstanceTableCell extends StatelessWidget {
  InstanceTableCell(
    ObjectSet objects,
    HeapDataCallback heap,
    HeapClassName heapClass, {
    required this.isSelected,
    required this.gaContext,
    this.liveItemsEnabled = true,
  })  : _showMenu = _shouldShowMenu(isSelected, objects),
        _sampleObtainer = _shouldShowMenu(isSelected, objects)
            ? HeapClassSampler(objects, heap(), heapClass)
            : null,
        _count = objects.instanceCount;

  static bool _shouldShowMenu(bool isSelected, ObjectSet objects) =>
      isSelected && objects.instanceCount > 0;

  final HeapClassSampler? _sampleObtainer;
  final bool _showMenu;
  final bool isSelected;
  final MemoryAreas gaContext;
  final int _count;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InstanceSetButton(
          textStyle:
              isSelected ? theme.selectedTextStyle : theme.regularTextStyle,
          count: _count,
          gaContext: gaContext,
          sampleObtainer: _sampleObtainer,
          showMenu: _showMenu,
          liveItemsEnabled: liveItemsEnabled,
        ),
      ],
    );
  }
}
