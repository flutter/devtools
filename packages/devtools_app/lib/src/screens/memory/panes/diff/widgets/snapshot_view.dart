// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/split.dart';
import '../../../shared/heap/heap.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/heap_diff.dart';
import 'class_details/class_details.dart';
import 'classes_table_diff.dart';
import 'classes_table_single.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeapClasses?>(
      valueListenable: controller.derived.heapClasses,
      builder: (_, classes, __) {
        print('!!!! rebuild snapshot view');

        if (classes == null) {
          if (controller.isProcessing.value) {
            return const SizedBox.shrink();
          } else {
            return const Center(child: Text('Could not take snapshot.'));
          }
        }

        late Widget classTable;

        if (classes is SingleHeapClasses) {
          classTable = ClassesTableSingle(
            classes: controller.derived.singleClassesToShow.value!,
            selection: controller.derived.selectedSingleClassStats,
          );
        } else if (classes is DiffHeapClasses) {
          classTable = ClassesTableDiff(
            classes: controller.derived.diffClassesToShow.value!,
            selection: controller.derived.selectedDiffClassStats,
          );
        } else {
          throw StateError('Unexpected type: ${classes.runtimeType}.');
        }

        final pathTable = ValueListenableBuilder<List<StatsByPathEntry>?>(
          valueListenable: controller.derived.pathEntries,
          builder: (_, entries, __) => HeapClassDetails(
            entries: entries,
            selection: controller.derived.selectedPathEntry,
            isDiff: classes is DiffHeapClasses,
            pathController: controller.retainingPathController,
            className: controller.core.className?.className,
          ),
        );

        return Split(
          axis: Axis.vertical,
          initialFractions: const [0.4, 0.6],
          minSizes: const [80, 80],
          children: [
            OutlineDecoration(child: classTable),
            OutlineDecoration(child: pathTable),
          ],
        );
      },
    );
  }
}
