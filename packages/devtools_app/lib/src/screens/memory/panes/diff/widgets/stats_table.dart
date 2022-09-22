// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';
import '../../../../../primitives/utils.dart';
import '../../../../../shared/table.dart';
import '../../../../../shared/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/model.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

class _ClassNameColumn extends ColumnData<HeapStatsRecord> {
  _ClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(100.0),
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(HeapStatsRecord record) => record.heapClass.className;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(HeapStatsRecord record) => record.heapClass.fullName;
}

class _InstanceColumn extends ColumnData<HeapStatsRecord> {
  _InstanceColumn()
      : super(
          'Non GC-able\nInstances',
          titleTooltip: 'Number of instances of the class '
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
          titleTooltip: 'Total shallow size of the instances.\n'
              'Shallow size of an object is size of this object plus\n'
              'the references it holds to other Dart objects in its fields\n'
              '(this does not include the size of the fields\n'
              ' - just the size of the references)',
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

class StatsTable extends StatefulWidget {
  const StatsTable({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final DiffPaneController controller;

  @override
  State<StatsTable> createState() => _StatsTableState();
}

class _StatsTableState extends State<StatsTable> with AutoDisposeMixin {
  late final List<ColumnData<HeapStatsRecord>> _columns;
  late final SnapshotListItem _item;

  @override
  void initState() {
    super.initState();

    _item = widget.controller.selectedItem as SnapshotListItem;

    final _shallowSizeColumn = _ShallowSizeColumn();

    _columns = <ColumnData<HeapStatsRecord>>[
      _ClassNameColumn(),
      _InstanceColumn(),
      _shallowSizeColumn,
      _RetainedSizeColumn(),
    ];

    if (!_item.sorting.initialized) {
      _item.sorting
        ..direction = SortDirection.descending
        ..columnIndex = _columns.indexOf(_shallowSizeColumn)
        ..initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlatTable<HeapStatsRecord>(
      columns: _columns,
      data: _item.statsToShow.records,
      keyFactory: (e) => Key(e.heapClass.fullName),
      onItemSelected: (r) =>
          widget.controller.setSelectedClass(r.heapClass.fullName),
      selectionNotifier: _item.selectedRecord,
      sortColumn: _columns[_item.sorting.columnIndex],
      sortDirection: _item.sorting.direction,
      onSortChanged: (
        sortColumn,
        direction, {
        secondarySortColumn,
      }) =>
          setState(() {
        _item.sorting.columnIndex = _columns.indexOf(sortColumn);
        _item.sorting.direction = direction;
      }),
    );
  }
}
