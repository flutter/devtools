// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/memory/new/classes.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/heap_diff.dart';
import '../controller/item_controller.dart';
import 'class_details/class_details.dart';
import 'classes_table_diff.dart';
import 'classes_table_single.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        controller.derived.singleClassesToShow,
        controller.derived.diffClassesToShow,
      ],
      builder: (_, values, __) {
        final singleClasses = values.first as ClassDataList<SingleClassData>?;
        final diffClasses = values.second as List<DiffClassStats>?;
        if (controller.derived.updatingValues) {
          return const Center(child: Text('Calculating...'));
        }

        final classes = controller.derived.heapClasses.value;
        if (classes == null) {
          final current = controller.core.selectedItem as SnapshotDataItem;
          return current.isProcessing.value
              ? const SizedBox.shrink()
              : const Center(child: Text('Could not take snapshot.'));
        }

        assert((singleClasses == null) != (diffClasses == null));

        late Widget classTable;

        if (singleClasses != null) {
          classTable = ClassesTableSingle(
            classes: singleClasses,
            classesData: controller.derived.classesTableSingle,
          );
        } else if (diffClasses != null) {
          classTable = ClassesTableDiff(
            classes: controller.derived.diffClassesToShow.value!,
            diffData: controller.derived.classesTableDiff,
          );
        } else {
          throw StateError('singleClasses or diffClasses should not be null.');
        }

        final pathTable = ValueListenableBuilder<ClassData?>(
          valueListenable: controller.derived.classData,
          builder: (_, classData, __) => HeapClassDetails(
            classData: classData,
            pathSelection: controller.derived.selectedPath,
            isDiff: classes is DiffHeapClasses,
            pathController: controller.retainingPathController,
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
