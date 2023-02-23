// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/split.dart';
import '../../../shared/heap/heap.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/heap_diff.dart';
import '../controller/item_controller.dart';
import 'class_details/class_details.dart';
import 'class_filter.dart';
import 'classes_table_diff.dart';
import 'classes_table_single.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder<List<SingleClassStats>?,
        List<DiffClassStats>?>(
      firstListenable: controller.derived.singleClassesToShow,
      secondListenable: controller.derived.diffClassesToShow,
      builder: (_, singleClasses, diffClasses, __) {
        if (controller.derived.updatingValues) {
          return const Center(child: Text('Calculating...'));
        }

        final classes = controller.derived.heapClasses.value;
        if (classes == null) {
          return controller.isTakingSnapshot.value
              ? const SizedBox.shrink()
              : const Center(child: Text('Could not take snapshot.'));
        }

        assert((singleClasses == null) != (diffClasses == null));

        late Widget classTable;

        final filter = controller.core.classFilter;

        final classFilterButton = ClassFilterButton(
          filter: filter,
          onChanged: controller.applyFilter,
          rootPackage: serviceManager.rootInfoNow().package,
        );

        if (singleClasses != null) {
          final totalSize =
              (controller.core.selectedItem as SnapshotInstanceItem).totalSize;
          classTable = ClassesTableSingle(
            classes: singleClasses,
            selection: controller.derived.selectedSingleClassStats,
            totalSize: totalSize!,
            classFilterButton: classFilterButton,
            heap:
                (controller.derived.selectedItem.value as SnapshotInstanceItem)
                    .heap!
                    .data,
          );
        } else if (diffClasses != null) {
          final diffHeapClasses =
              controller.derived.heapClasses.value as DiffHeapClasses;
          classTable = ClassesTableDiff(
            classes: controller.derived.diffClassesToShow.value!,
            selection: controller.derived.selectedDiffClassStats,
            classFilterButton: classFilterButton,
            before: diffHeapClasses.before,
            after: diffHeapClasses.after,
          );
        } else {
          throw StateError('singleClasses or diffClasses should not be null.');
        }

        final pathTable = ValueListenableBuilder<List<StatsByPathEntry>?>(
          valueListenable: controller.derived.pathEntries,
          builder: (_, entries, __) => HeapClassDetails(
            entries: entries,
            selection: controller.derived.selectedPathEntry,
            isDiff: classes is DiffHeapClasses,
            pathController: controller.retainingPathController,
            className: controller.core.className_?.className,
          ),
        );

        return Split(
          axis: Axis.vertical,
          initialFractions: const [0.4, 0.6],
          minSizes: const [80, 80],
          children: [
            OutlineDecoration.onlyBottom(
              child: classTable,
            ),
            OutlineDecoration.onlyTop(
              child: pathTable,
            ),
          ],
        );
      },
    );
  }
}
