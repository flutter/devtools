// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../../../primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/primitives.dart';
import '../../../shared/shared_memory_widgets.dart';
import '../controller/heap_diff.dart';

enum _DataPart {
  created,
  deleted,
  delta,
}

enum _SizeType {
  shallow,
  retained,
}

class _ClassNameColumn extends ColumnData<DiffClassStats>
    implements ColumnRenderer<DiffClassStats> {
  _ClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(180.0),
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(DiffClassStats classStats) => classStats.heapClass.className;

  @override
  bool get supportsSorting => true;

  @override
  // We are removing the tooltip, because it is provided by [HeapClassView].
  String getTooltip(DiffClassStats classStats) => '';

  @override
  Widget build(
    BuildContext context,
    DiffClassStats data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) =>
      HeapClassView(theClass: data.heapClass, showCopyButton: isRowSelected);
}

class _InstanceColumn extends ColumnData<DiffClassStats> {
  _InstanceColumn(this.dataPart)
      : super(
          columnTitle(dataPart),
          fixedWidthPx: scaleByFontFactor(80.0),
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
        return classStats.total.delta.instanceCount;
    }
  }

  @override
  bool get numeric => true;
}

class _SizeColumn extends ColumnData<DiffClassStats> {
  _SizeColumn(this.dataPart, this.sizeType)
      : super(
          columnTitle(dataPart),
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  final _DataPart dataPart;
  final _SizeType sizeType;

  static String columnTitle(_DataPart dataPart) {
    switch (dataPart) {
      case _DataPart.created:
        return 'Allocated';
      case _DataPart.deleted:
        return 'Freed';
      case _DataPart.delta:
        return 'Delta';
    }
  }

  @override
  int getValue(DiffClassStats classStats) {
    switch (sizeType) {
      case _SizeType.shallow:
        switch (dataPart) {
          case _DataPart.created:
            return classStats.total.created.shallowSize;
          case _DataPart.deleted:
            return classStats.total.deleted.shallowSize;
          case _DataPart.delta:
            return classStats.total.delta.shallowSize;
        }
      case _SizeType.retained:
        switch (dataPart) {
          case _DataPart.created:
            return classStats.total.created.retainedSize;
          case _DataPart.deleted:
            return classStats.total.deleted.retainedSize;
          case _DataPart.delta:
            return classStats.total.delta.retainedSize;
        }
    }
  }

  @override
  String getDisplayValue(DiffClassStats classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;

  @override
  bool get numeric => true;
}

class ClassesTableDiff extends StatelessWidget {
  const ClassesTableDiff({
    Key? key,
    required this.classes,
    required this.selection,
  }) : super(key: key);

  final DiffHeapClasses classes;
  final ValueNotifier<DiffClassStats?> selection;

  static final _columnGroups = [
    ColumnGroup(
      title: '',
      range: const Range(0, 1),
    ),
    ColumnGroup(
      title: 'Instances',
      range: const Range(1, 4),
      tooltip: nonGcableInstancesColumnTooltip,
    ),
    ColumnGroup(
      title: 'Shallow Dart Size',
      range: const Range(4, 7),
      tooltip: shallowSizeColumnTooltip,
    ),
    ColumnGroup(
      title: 'Retained Dart Size',
      range: const Range(7, 10),
      tooltip: retainedSizeColumnTooltip,
    ),
  ];

  static final _retainedSizeDeltaColumn =
      _SizeColumn(_DataPart.delta, _SizeType.retained);

  static late final List<ColumnData<DiffClassStats>> _columns =
      <ColumnData<DiffClassStats>>[
    _ClassNameColumn(),
    _InstanceColumn(_DataPart.created),
    _InstanceColumn(_DataPart.deleted),
    _InstanceColumn(_DataPart.delta),
    _SizeColumn(_DataPart.created, _SizeType.shallow),
    _SizeColumn(_DataPart.deleted, _SizeType.shallow),
    _SizeColumn(_DataPart.delta, _SizeType.shallow),
    _SizeColumn(_DataPart.created, _SizeType.retained),
    _SizeColumn(_DataPart.deleted, _SizeType.retained),
    _retainedSizeDeltaColumn,
  ];

  @override
  Widget build(BuildContext context) {
    return FlatTable<DiffClassStats>(
      columns: _columns,
      columnGroups: _columnGroups,
      data: classes.classes,
      dataKey: 'ClassesTableDiff',
      keyFactory: (e) => Key(e.heapClass.fullName),
      selectionNotifier: selection,
      defaultSortColumn: _retainedSizeDeltaColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
