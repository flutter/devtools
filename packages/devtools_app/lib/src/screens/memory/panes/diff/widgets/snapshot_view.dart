// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/split.dart';
import '../../../shared/heap/heap.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/heap_diff.dart';
import '../controller/item_controller.dart';
import 'class_details.dart';
import 'classes_table_diff.dart';
import 'classes_table_single.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotItem>(
      valueListenable: controller.data.derived.selectedItem,
      builder: (_, item, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: item.isProcessing,
          builder: (_, isProcessing, __) {
            if (isProcessing) return const SizedBox.shrink();

            if (item is! SnapshotInstanceItem) {
              throw StateError('Unexpected type: ${item.runtimeType}.');
            }

            if (item.heap == null) {
              return const Center(child: Text('Could not take snapshot.'));
            }

            final table1 = ValueListenableBuilder<HeapClasses?>(
              valueListenable: controller.data.derived.heapClasses,
              builder: (_, classes, __) {
                if (classes is SingleHeapClasses) {
                  return ClassesTableSingle(
                    classes: classes,
                    selection: controller.data.derived.singleClassStats,
                  );
                } else if (classes is DiffHeapClasses) {
                  return ClassesTableDiff(
                    classes: classes,
                    selection: controller.data.derived.diffClassStats,
                  );
                } else {
                  throw StateError('Unexpected type: ${classes.runtimeType}.');
                }
              },
            );

            final table2 = ValueListenableBuilder<List<StatsByPathEntry>?>(
              valueListenable: controller.data.derived.pathEntries,
              builder: (_, entries, __) => HeapClassDetails(
                entries: entries,
                selection: controller.data.derived.pathEntry,
              ),
            );

            return Split(
              axis: Axis.vertical,
              initialFractions: const [0.4, 0.6],
              minSizes: const [80, 80],
              children: [
                OutlineDecoration(child: table1),
                OutlineDecoration(child: table2),
              ],
            );
          },
        );
      },
    );
  }
}
