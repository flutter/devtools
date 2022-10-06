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

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.entries,
    required this.selection,
  }) : super(key: key);

  final List<StatsByPathEntry>? entries;
  final ValueNotifier<StatsByPathEntry?> selection;

  @override
  Widget build(BuildContext context) {
    final theEntries = entries;
    if (theEntries == null) {
      return const Center(
        child: Text('Select class to see details here.'),
      );
    }

    return _RetainingPathTable(
      entries: theEntries,
      selection: selection,
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
  bool get numeric => true;

  @override
  String getDisplayValue(StatsByPathEntry record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainingPathTable extends StatelessWidget {
  const _RetainingPathTable({
    Key? key,
    required this.entries,
    required this.selection,
  }) : super(key: key);

  final List<StatsByPathEntry> entries;
  final ValueNotifier<StatsByPathEntry?> selection;

  static final _shallowSizeColumn = _ShallowSizeColumn();
  static late final List<ColumnData<StatsByPathEntry>> _columns =
      <ColumnData<StatsByPathEntry>>[
    _RetainingPathColumn(),
    _InstanceColumn(),
    _shallowSizeColumn,
    _RetainedSizeColumn(),
  ];

  @override
  Widget build(BuildContext context) {
    return FlatTable<StatsByPathEntry>(
      dataKey: 'RetainingPathTable',
      columns: _columns,
      data: entries,
      keyFactory: (e) => Key(e.key.asLongString()),
      selectionNotifier: selection,
      defaultSortColumn: _shallowSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
