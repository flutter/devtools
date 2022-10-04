// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/primitives.dart';
import '../controller/item_controller.dart';

class _RetainingPathColumn extends ColumnData<RetainingPathRecord> {
  _RetainingPathColumn()
      : super.wide(
          'Retaining Path',
          titleTooltip: 'Class names of objects that retain'
              '\nthe instances from garbage collection.',
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(RetainingPathRecord record) => record.key.asShortString();

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(RetainingPathRecord record) =>
      record.key.asMultiLineString();
}

class _InstanceColumn extends ColumnData<RetainingPathRecord> {
  _InstanceColumn()
      : super(
          'Instances',
          titleTooltip: 'Number of instances of the class\n'
              'retained by the path.',
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(RetainingPathRecord record) => record.value.instanceCount;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<RetainingPathRecord> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: shallowSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(RetainingPathRecord record) => record.value.shallowSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(RetainingPathRecord record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<RetainingPathRecord> {
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(RetainingPathRecord record) => record.value.retainedSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(RetainingPathRecord record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class ClassStatsRetainingPathTable extends StatelessWidget {
  const ClassStatsRetainingPathTable({
    Key? key,
    required this.data,
  }) : super(key: key);

  final List<RetainingPathRecord> data;

  static final _shallowSizeColumn = _ShallowSizeColumn();

  static final _columns = [
    _RetainingPathColumn(),
    _InstanceColumn(),
    _shallowSizeColumn,
    _RetainedSizeColumn(),
  ];

  @override
  Widget build(BuildContext context) {
    return FlatTable<RetainingPathRecord>(
      keyFactory: (e) => Key(e.key.asMultiLineString()),
      columns: _columns,
      data: data,
      dataKey: 'class-stats-retaining-path',
      defaultSortColumn: _shallowSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
