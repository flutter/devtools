// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../../../primitives/utils.dart';

import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/primitives.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.controller,
    required this.item,
  }) : super(key: key);

  final DiffPaneController controller;
  final SnapshotInstanceItem item;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ClassStats?>(
      valueListenable: item.selectedClassStats,
      builder: (_, classStats, __) {
        if (classStats == null) {
          return const Center(
            child: Text('Select class to see details here.'),
          );
        }

        return _RetainingPathTable(
          data: classStats,
          controller: controller,
          item: item,
        );
      },
    );
  }
}

class _RetainingPathColumn extends ColumnData<StatsByPathEntry> {
  _RetainingPathColumn()
      : super.wide(
          'Retaining Path',
          titleTooltip: 'Class names of objects that retain'
              '\nthe instances from garbage collection.',
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(StatsByPathEntry record) => record.key.asShortString();

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(StatsByPathEntry record) => record.key.asLongString();
}

class _InstanceColumn extends ColumnData<StatsByPathEntry> {
  _InstanceColumn()
      : super(
          'Instances',
          titleTooltip: 'Number of instances of the class\n'
              'retained by the path.',
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(StatsByPathEntry record) => record.value.instanceCount;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<StatsByPathEntry> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: shallowSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(StatsByPathEntry record) => record.value.shallowSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(StatsByPathEntry record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<StatsByPathEntry> {
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(StatsByPathEntry record) => record.value.retainedSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(StatsByPathEntry record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainingPathTable extends StatelessWidget {
  _RetainingPathTable({
    Key? key,
    required this.data,
    required this.controller,
    required this.item,
  }) : super(key: key) {
    _columns = <ColumnData<StatsByPathEntry>>[
      _RetainingPathColumn(),
      _InstanceColumn(),
      _shallowSizeColumn,
      _RetainedSizeColumn(),
    ];
  }

  final ClassStats data;
  final SnapshotInstanceItem item;
  final DiffPaneController controller;

  late final List<ColumnData<StatsByPathEntry>> _columns;
  final _shallowSizeColumn = _ShallowSizeColumn();

  @override
  Widget build(BuildContext context) {
    return FlatTable<StatsByPathEntry>(
      dataKey: identityHashCode(data).toString(),
      columns: _columns,
      data: data.statsByPathEntries,
      keyFactory: (e) => Key(e.key.asLongString()),
      selectionNotifier: item.selectedPathEntry,
      onItemSelected: (r) => controller.setselectedPath(r?.key),
      defaultSortColumn: _shallowSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
