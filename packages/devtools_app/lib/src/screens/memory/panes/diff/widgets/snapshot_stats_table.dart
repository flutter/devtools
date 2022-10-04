// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/primitives.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

class _ClassNameColumn extends ColumnData<HeapClassStatistics> {
  _ClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(100.0),
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(HeapClassStatistics classStats) =>
      classStats.heapClass.className;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(HeapClassStatistics classStats) =>
      classStats.heapClass.fullName;
}

class _InstanceColumn extends ColumnData<HeapClassStatistics> {
  _InstanceColumn()
      : super(
          'Non GC-able\nInstances',
          titleTooltip: 'Number of instances of the class\n'
              'that have a retaining path from the root\n'
              'and therefore can’t be garbage collected.',
          fixedWidthPx: scaleByFontFactor(110.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapClassStatistics classStats) =>
      classStats.total.instanceCount;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<HeapClassStatistics> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: shallowSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapClassStatistics classStats) => classStats.total.shallowSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(HeapClassStatistics classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<HeapClassStatistics> {
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapClassStatistics classStats) => classStats.total.retainedSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(HeapClassStatistics classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class SnapshotStatsTable extends StatelessWidget {
  const SnapshotStatsTable({
    Key? key,
    required this.item,
    required this.dataId,
    required this.controller,
  }) : super(key: key);

  final SnapshotListItem item;

  final int dataId;

  final DiffPaneController controller;

  static final _shallowSizeColumn = _ShallowSizeColumn();

  static final List<ColumnData<HeapClassStatistics>> _columns = [
    _ClassNameColumn(),
    _InstanceColumn(),
    _shallowSizeColumn,
    _RetainedSizeColumn(),
  ];

  @override
  Widget build(BuildContext context) {
    final data = item.statsToShow.classStats;
    return FlatTable<HeapClassStatistics>(
      keyFactory: (e) => Key(e.heapClass.fullName),
      data: data,
      dataKey: 'snapshot-stats-$dataId',
      columns: _columns,
      selectionNotifier: item.selectedClassStats,
      onItemSelected: (classStats) =>
          controller.selectedClassName.value = classStats?.heapClass.fullName,
      defaultSortColumn: _shallowSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
