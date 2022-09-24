// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/split.dart';
import '../../../shared/heap/heap.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';
import 'class_details.dart';
import 'snapshot_stats_table.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.selectedItem as SnapshotListItem;
    return ValueListenableBuilder<bool>(
      valueListenable: item.isProcessing,
      builder: (_, isProcessing, __) {
        if (isProcessing) return const SizedBox.shrink();

        late HeapStatistics? stats;
        if (item.diffWith.value == null) {
          stats = item.heap?.stats;
        } else {
          final heap1 = item.heap!;
          final heap2 = item.diffWith.value!.heap!;

          // TODO(polina-c): make comparison async.
          stats = controller.diffStore.compare(heap1, heap2).stats;
        }

        if (stats == null) {
          return const Center(child: Text('Could not take snapshot.'));
        }

        return ValueListenableBuilder<SnapshotListItem?>(
          valueListenable: item.diffWith,
          builder: (_, diffWith, __) {
            return Split(
              axis: Axis.vertical,
              initialFractions: const [0.4, 0.6],
              minSizes: const [80, 80],
              children: [
                OutlineDecoration(
                  child: SnapshotStatsTable(
                    // The key is passed to persist state.
                    key: ObjectKey(item),
                    controller: controller,
                  ),
                ),
                OutlineDecoration(
                  child: HeapClassDetails(
                    item: item,
                    sorting: controller.classStatsSorting,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
