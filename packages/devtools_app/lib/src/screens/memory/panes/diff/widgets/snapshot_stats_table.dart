// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';
import '../../../../../primitives/utils.dart';
import '../../../../../shared/table.dart';
import '../../../../../shared/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/primitives.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

class _ClassNameColumn extends ColumnData<SingleHeapClass> {
  _ClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(100.0),
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(SingleHeapClass classStats) =>
      classStats.heapClass.className;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(SingleHeapClass classStats) =>
      classStats.heapClass.fullName;
}

class _InstanceColumn extends ColumnData<SingleHeapClass> {
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
  int getValue(SingleHeapClass classStats) => classStats.objects.instanceCount;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<SingleHeapClass> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: shallowSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(SingleHeapClass classStats) => classStats.objects.shallowSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleHeapClass classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<SingleHeapClass> {
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(SingleHeapClass classStats) => classStats.objects.retainedSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleHeapClass classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class SingleSnapshotTable extends StatefulWidget {
  const SingleSnapshotTable({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final DiffPaneController controller;

  @override
  State<SingleSnapshotTable> createState() => _SingleSnapshotTableState();
}

class _SingleSnapshotTableState extends State<SingleSnapshotTable>
    with AutoDisposeMixin {
  late final List<ColumnData<SingleHeapClass>> _columns;
  late final SnapshotInstanceItem _item;
  late final SingeHeapClasses _classes;

  @override
  void initState() {
    super.initState();

    _item = widget.controller.selectedSnapshotItem as SnapshotInstanceItem;
    _classes = _item.heapClassesToShow as SingeHeapClasses;

    final _shallowSizeColumn = _ShallowSizeColumn();

    _columns = <ColumnData<SingleHeapClass>>[
      _ClassNameColumn(),
      _InstanceColumn(),
      _shallowSizeColumn,
      _RetainedSizeColumn(),
    ];

    final sorting = widget.controller.classSorting;
    if (!sorting.initialized) {
      sorting
        ..direction = SortDirection.descending
        ..columnIndex = _columns.indexOf(_shallowSizeColumn)
        ..initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorting = widget.controller.classSorting;
    return FlatTable<SingleHeapClass>(
      columns: _columns,
      data: _classes.classes,
      keyFactory: (e) => Key(e.heapClass.fullName),
      onItemSelected: (r) => widget.controller.setSelectedClass(r.heapClass),
      //selectionNotifier: null, //  _item.selectedHeapClass, ??????????
      sortColumn: _columns[sorting.columnIndex],
      sortDirection: sorting.direction,
      onSortChanged: (
        sortColumn,
        direction, {
        secondarySortColumn,
      }) =>
          setState(() {
        sorting.columnIndex = _columns.indexOf(sortColumn);
        sorting.direction = direction;
      }),
    );
  }
}
