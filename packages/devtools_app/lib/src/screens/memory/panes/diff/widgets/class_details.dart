// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../shared/heap/heap.dart';
import '../controller/item_controller.dart';
import '../controller/model.dart';
import 'class_stats_table.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.item,
    required this.sorting,
  }) : super(key: key);

  final SnapshotListItem item;
  final ColumnSorting sorting;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeapClassStatistics?>(
      valueListenable: item.selectedClassStats,
      builder: (_, classStats, __) {
        if (classStats == null) {
          return const Center(
            child: Text('Select class to see details here.'),
          );
        }

        return ClassStatsTable(
          data: classStats,
          sorting: sorting,
        );
      },
    );
  }
}
