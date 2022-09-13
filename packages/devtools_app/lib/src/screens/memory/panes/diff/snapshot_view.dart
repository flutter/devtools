// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/table.dart';
import '../../../../shared/table_data.dart';
import '../../../../shared/utils.dart';
import '../../shared/heap/model.dart';
import 'model.dart';

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
        if (stats == null) return const Text('Could not take snapshot.');

        return StatsTable(data: stats);
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
}

class _InstanceColumn extends ColumnData<HeapStatsRecord> {
  _InstanceColumn()
      : super(
          'Retained\nInstances',
          titleTooltip: 'Number of instances of the class, '
              'that have retaining path from the root.',
          fixedWidthPx: scaleByFontFactor(85.0),
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
          'Shallow\nSize',
          titleTooltip: 'Total shallow Dart (not native) size of objects.',
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapStatsRecord record) => record.shallowSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class _RetainedSizeColumn extends ColumnData<HeapStatsRecord> {
  _RetainedSizeColumn()
      : super(
          'Retained\nSize',
          titleTooltip:
              'Total size of objects plus objects they retain in the memory, '
              'taking to account only shortest retaining path for the referenced objects.',
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(HeapStatsRecord record) => record.retainedSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class StatsTable extends StatefulWidget {
  const StatsTable({Key? key, required this.data}) : super(key: key);
  final List<HeapStatsRecord> data;

  @override
  State<StatsTable> createState() => _StatsTableState();
}

class _StatsTableState extends State<StatsTable> {
  late final List<ColumnData<HeapStatsRecord>> columns;
  final _retainedSizeColumn = _RetainedSizeColumn();

  @override
  void initState() {
    super.initState();

    columns = <ColumnData<HeapStatsRecord>>[
      _ClassNameColumn(),
      _InstanceColumn(),
      _ShallowSizeColumn(),
      _retainedSizeColumn,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FlatTable<HeapStatsRecord>(
      columns: columns,
      data: widget.data,
      keyFactory: (e) => Key(e.fullClassName),
      onItemSelected: (r) {},
      sortColumn: _retainedSizeColumn,
      sortDirection: SortDirection.ascending,
    );
  }
}
