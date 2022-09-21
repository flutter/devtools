// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/split.dart';
import '../../../shared/heap/model.dart';
import '../controller/heap_diff.dart';
import '../controller/model.dart';
import 'class_details.dart';
import 'stats_table.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.item, required this.diffStore})
      : super(key: key);

  final SnapshotListItem item;
  final HeapDiffStore diffStore;

  @override
  Widget build(BuildContext context) {
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
          stats = diffStore.compare(heap1, heap2).stats;
        }

        if (stats == null) {
          return const Center(child: Text('Could not take snapshot.'));
        }

        return ValueListenableBuilder<SnapshotListItem?>(
          valueListenable: item.diffWith,
          builder: (_, diffWith, __) {
            return Split(
              axis: Axis.horizontal,
              initialFractions: const [0.5, 0.5],
              minSizes: const [80, 80],
              children: [
                OutlineDecoration(
                  child: StatsTable(
                    // The key is passed to persist state.
                    key: ObjectKey(item),
                    data: item.statsToShow,
                    sorting: item.sorting,
                    selectedRecord: item.selectedRecord,
                  ),
                ),
                const OutlineDecoration(
                  child: ClassDetails(heapClass: null),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
