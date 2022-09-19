// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/utils.dart';
import '../../../../../shared/table.dart';
import '../../../../../shared/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/model.dart';
import '../controller/model.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.item}) : super(key: key);

  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: item.isProcessing,
      builder: (_, isProcessing, __) {
        if (isProcessing) return const SizedBox.shrink();

        final stats = item.stats;
        if (stats == null) {
          return const Center(child: Text('Could not take snapshot.'));
        }

        return _StatsTable(
          // The key is passed to persist state.
          key: ObjectKey(item),
          data: stats,
          sorting: item.sorting,
          selectedRecord: item.selectedRecord,
        );
      },
    );
  }
}

class _ClassNameColumn extends ColumnData<HeapStatsRecord> {
  _ClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(100.0),
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(HeapStatsRecord record) => record.className;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(HeapStatsRecord record) => record.fullClassName;
}

class _InstanceColumn extends ColumnData<HeapStatsRecord> {
  _InstanceColumn()
      : super(
          'Non GC-able\nInstances',
          titleTooltip: 'Number of instances of the class, '
              'that have a retaining path from the root.',
          fixedWidthPx: scaleByFontFactor(110.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapStatsRecord record) => record.instanceCount;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<HeapStatsRecord> {
  _ShallowSizeColumn()
      : super(
          'Shallow\n Dart Size',
          titleTooltip: 'Total shallow Dart size (sum of all references '
              "to the Dart object's fields) of objects.",
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapStatsRecord record) => record.shallowSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(HeapStatsRecord record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<HeapStatsRecord> {
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip:
              'Total shallow Dart size of objects plus shallow Dart size of objects they retain,\n'
              'taking into account only the shortest retaining path for the referenced objects.',
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapStatsRecord record) => record.retainedSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(HeapStatsRecord record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _StatsTable extends StatefulWidget {
  const _StatsTable({
    Key? key,
    required this.data,
    required this.sorting,
    required this.selectedRecord,
  }) : super(key: key);

  final HeapStatistics data;
  final ValueNotifier<HeapStatsRecord?> selectedRecord;
  final ColumnSorting sorting;

  @override
  State<_StatsTable> createState() => _StatsTableState();
}

class _StatsTableState extends State<_StatsTable> {
  late final List<ColumnData<HeapStatsRecord>> _columns;

  @override
  void initState() {
    super.initState();

    final _shallowSizeColumn = _ShallowSizeColumn();

    _columns = <ColumnData<HeapStatsRecord>>[
      _ClassNameColumn(),
      _InstanceColumn(),
      _shallowSizeColumn,
      _RetainedSizeColumn(),
    ];

    if (!widget.sorting.initialized) {
      widget.sorting
        ..direction = SortDirection.descending
        ..columnIndex = _columns.indexOf(_shallowSizeColumn)
        ..initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlatTable<HeapStatsRecord>(
      columns: _columns,
      data: widget.data.list,
      keyFactory: (e) => Key(e.fullClassName),
      onItemSelected: (r) => widget.selectedRecord.value = r,
      selectionNotifier: widget.selectedRecord,
      sortColumn: _columns[widget.sorting.columnIndex],
      sortDirection: widget.sorting.direction,
      onSortChanged: (
        sortColumn,
        direction, {
        secondarySortColumn,
      }) =>
          setState(() {
        widget.sorting.columnIndex = _columns.indexOf(sortColumn);
        widget.sorting.direction = direction;
      }),
    );
  }
}
