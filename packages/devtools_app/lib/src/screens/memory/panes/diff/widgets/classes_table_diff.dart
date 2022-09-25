// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../controller/heap_diff.dart';

import 'package:flutter/material.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';
import '../../../../../primitives/utils.dart';
import '../../../../../shared/table.dart';
import '../../../../../shared/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/primitives.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

enum _DataPart {
  created,
  deleted,
  delta,
}

class _ClassNameColumn extends ColumnData<DiffClassStats> {
  _ClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(100.0),
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(DiffClassStats classStats) => classStats.heapClass.className;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(DiffClassStats classStats) => classStats.heapClass.fullName;
}

class _InstanceColumn extends ColumnData<DiffClassStats> {
  _InstanceColumn(this.dataPart)
      : super(
          columnTitle(dataPart),
          fixedWidthPx: scaleByFontFactor(110.0),
          alignment: ColumnAlignment.right,
        );

  final _DataPart dataPart;

  static String columnTitle(_DataPart dataPart) {
    switch (dataPart) {
      case _DataPart.created:
        return 'New';
      case _DataPart.deleted:
        return 'Deleted';
      case _DataPart.delta:
        return 'Delta';
    }
  }

  @override
  int getValue(DiffClassStats classStats) {
    switch (dataPart) {
      case _DataPart.created:
        return classStats.total.created.instanceCount;
      case _DataPart.deleted:
        return classStats.total.deleted.instanceCount;
      case _DataPart.delta:
        return classStats.total.deleted.instanceCount;
    }
  }

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<DiffClassStats> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: shallowSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(DiffClassStats classStats) => 1;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(DiffClassStats classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<DiffClassStats> {
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(DiffClassStats classStats) => 1;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(DiffClassStats classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class ClassesTableDiff extends StatefulWidget {
  const ClassesTableDiff({
    Key? key,
    required this.classes,
    required this.controller,
  }) : super(key: key);

  final DiffHeapClasses classes;
  final DiffPaneController controller;

  @override
  State<ClassesTableDiff> createState() => _ClassesTableDiffState();
}

class _ClassesTableDiffState extends State<ClassesTableDiff>
    with AutoDisposeMixin {
  late final List<ColumnData<DiffClassStats>> _columns;
  late final SnapshotInstanceItem _item;

  @override
  void initState() {
    super.initState();

    _item = widget.controller.selectedSnapshotItem as SnapshotInstanceItem;

    final _shallowSizeDeltaColumn = _ShallowSizeColumn();

    _columns = <ColumnData<DiffClassStats>>[
      _ClassNameColumn(),
      _InstanceColumn(_DataPart.created),
      _InstanceColumn(_DataPart.deleted),
      _InstanceColumn(_DataPart.delta),
      _ShallowSizeColumn(),
      _ShallowSizeColumn(),
      _shallowSizeDeltaColumn,
      _RetainedSizeColumn(),
      _RetainedSizeColumn(),
      _RetainedSizeColumn(),
    ];

    final sorting = widget.controller.classSorting;
    if (!sorting.initialized) {
      sorting
        ..direction = SortDirection.descending
        ..columnIndex = _columns.indexOf(_shallowSizeDeltaColumn)
        ..initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorting = widget.controller.classSorting;
    return FlatTable<DiffClassStats>(
      columns: _columns,
      data: widget.classes.classes,
      keyFactory: (e) => Key(e.heapClass.fullName),
      onItemSelected: (r) => widget.controller.setSelectedClass(r.heapClass),
      selectionNotifier: _item.selectedDiffHeapClass,
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
