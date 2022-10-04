// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';
import '../../../../../primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/utils.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/heap_diff.dart';
import '../controller/item_controller.dart';

enum _DataPart {
  created,
  deleted,
  delta,
}

enum _SizeType {
  shallow,
  retained,
}

class _ClassNameColumn extends ColumnData<DiffClassStats> {
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
  String getTooltip(DiffClassStats classStats) => classStats.heapClass.fullName;
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

class ClassesTableDiff extends StatefulWidget {
  const ClassesTableDiff({
    Key? key,
    required this.classes,
    required this.selection,
  }) : super(key: key);

  final DiffHeapClasses classes;
  final ValueNotifier<DiffClassStats?> selection;

  @override
  State<ClassesTableDiff> createState() => _ClassesTableDiffState();
}

class _ClassesTableDiffState extends State<ClassesTableDiff>
    with AutoDisposeMixin {
  static final _columnGroups = [
    ColumnGroup(
      title: '',
      range: const Range(0, 1),
    ),
    ColumnGroup(
      title: 'Non GC-able Instances',
      range: const Range(1, 4),
    ),
    ColumnGroup(
      title: 'Shallow Dart Size',
      range: const Range(4, 7),
    ),
    ColumnGroup(
      title: 'Retained Dart Size',
      range: const Range(7, 10),
    ),
  ];

  static late final SnapshotInstanceItem _item;

  static final _shallowSizeDeltaColumn =
      _SizeColumn(_DataPart.delta, _SizeType.shallow);
  static late final List<ColumnData<DiffClassStats>> _columns =
      <ColumnData<DiffClassStats>>[
    _ClassNameColumn(),
    _InstanceColumn(_DataPart.created),
    _InstanceColumn(_DataPart.deleted),
    _InstanceColumn(_DataPart.delta),
    _SizeColumn(_DataPart.created, _SizeType.shallow),
    _SizeColumn(_DataPart.deleted, _SizeType.shallow),
    _shallowSizeDeltaColumn,
    _SizeColumn(_DataPart.created, _SizeType.retained),
    _SizeColumn(_DataPart.deleted, _SizeType.retained),
    _SizeColumn(_DataPart.delta, _SizeType.retained),
  ];

  @override
  Widget build(BuildContext context) {
    return FlatTable<DiffClassStats>(
      columns: _columns,
      columnGroups: _columnGroups,
      data: widget.classes.classes,
      dataKey: _item.id.toString(),
      keyFactory: (e) => Key(e.heapClass.fullName),
      selectionNotifier: widget.selection,
      defaultSortColumn: _shallowSizeDeltaColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
