// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';
import '../../../../../primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import '../../../shared/heap/primitives.dart';

typedef _RetainingPathRecord = MapEntry<ClassOnlyHeapPath, ObjectSetStats>;

class _RetainingPathColumn extends ColumnData<_RetainingPathRecord> {
  _RetainingPathColumn()
      : super.wide(
          'Shortest Retaining Path',
          titleTooltip: 'Class names of objects that retain'
              '\nthe instances from garbage collection.',
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(_RetainingPathRecord record) => record.key.asShortString();

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(_RetainingPathRecord record) => record.key.asLongString();
}

class _InstanceColumn extends ColumnData<_RetainingPathRecord> {
  _InstanceColumn()
      : super(
          'Instances',
          titleTooltip: 'Number of instances of the class\n'
              'retained by the path.',
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(_RetainingPathRecord record) => record.value.instanceCount;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<_RetainingPathRecord> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: shallowSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(_RetainingPathRecord record) => record.value.shallowSize;


  @override
  bool get numeric => true;

  @override
  String getDisplayValue(_RetainingPathRecord record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<_RetainingPathRecord> {
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(_RetainingPathRecord record) => record.value.retainedSize;


  @override
  bool get numeric => true;

  @override
  String getDisplayValue(_RetainingPathRecord record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class ClassStatsTable extends StatefulWidget {
  const ClassStatsTable({
    Key? key,
    required this.data,
  }) : super(key: key);

  final SingleClassStats data;

  @override
  State<ClassStatsTable> createState() => _ClassStatsTableState();
}

class _ClassStatsTableState extends State<ClassStatsTable>
    with AutoDisposeMixin {
  final _shallowSizeColumn = _ShallowSizeColumn();
  late final List<ColumnData<_RetainingPathRecord>> _columns;

  @override
  void initState() {
    super.initState();
    assert(widget.data.isSealed);

    _columns = <ColumnData<_RetainingPathRecord>>[
      _RetainingPathColumn(),
      _InstanceColumn(),
      _shallowSizeColumn,
      _RetainedSizeColumn(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FlatTable<_RetainingPathRecord>(
      columns: _columns,
      data: widget.data.entries,
      keyFactory: (e) => Key(e.key.asLongString()),
      // We want sorting to be the same for all snapshots and classes.
      dataKey: '',
      onItemSelected: (r) => {},
      defaultSortColumn: _shallowSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
