// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/split.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';
import 'class_details.dart';
import 'classes_table_diff.dart';
import 'classes_table_single.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.selectedSnapshotItem as SnapshotInstanceItem;
    return ValueListenableBuilder<bool>(
      valueListenable: item.isProcessing,
      builder: (_, isProcessing, __) {
        if (isProcessing) return const SizedBox.shrink();

        return ValueListenableBuilder<SnapshotInstanceItem?>(
          valueListenable: item.diffWith,
          builder: (_, diffWith, __) {
            if (item.heap == null) {
              return const Center(child: Text('Could not take snapshot.'));
            }

            late Widget table1;

            if (diffWith == null) {
              table1 = ClassesTableSingle(
                // The key is passed to persist state.
                key: ObjectKey(item),
                controller: controller,
              );
            } else {
              final heap1 = item.heap!;
              final heap2 = diffWith.heap!;

              // TODO(polina-c): make comparison async.
              final classes = controller.diffStore.compare(heap1, heap2);
              table1 = ClassesTableDiff(classes: classes);
            }

            const Widget table2 = HeapClassDetails(
                // item: item,
                // sorting: controller.pathSorting,
                );

            return Split(
              axis: Axis.vertical,
              initialFractions: const [0.4, 0.6],
              minSizes: const [80, 80],
              children: [
                OutlineDecoration(child: table1),
                const OutlineDecoration(child: table2),
              ],
            );
          },
        );
      },
    );
  }
}
