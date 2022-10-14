// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../../../../primitives/utils.dart';
import '../../../../../../shared/table/table.dart';
import '../../../../../../shared/table/table_data.dart';
import '../../../../../../shared/utils.dart';
import '../../../../shared/heap/heap.dart';
import '../../../../shared/heap/primitives.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.entries,
    required this.selection,
    required this.isDiff,
  }) : super(key: key);

  final List<StatsByPathEntry>? entries;
  final ValueNotifier<StatsByPathEntry?> selection;
  final bool isDiff;

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
      isDiff: isDiff,
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
  _InstanceColumn(bool isDiff)
      : super(
          isDiff ? 'Instances\nDelta' : 'Instances',
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
  _ShallowSizeColumn(bool isDiff)
      : super(
          isDiff ? 'Shallow\nSize Delta' : 'Shallow\nDart Size',
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
  _RetainedSizeColumn(bool isDiff)
      : super(
          isDiff ? 'Retained\nSize Delta' : 'Retained\nDart Size',
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

class _RetainingPathTableColumns {
  _RetainingPathTableColumns(this.isDiff);

  final bool isDiff;
  late final shallowSizeColumn = _ShallowSizeColumn(isDiff);
  late final columnList = <ColumnData<StatsByPathEntry>>[
    _RetainingPathColumn(),
    _InstanceColumn(isDiff),
    shallowSizeColumn,
    _RetainedSizeColumn(isDiff),
  ];
}

class _RetainingPathTable extends StatelessWidget {
  const _RetainingPathTable({
    Key? key,
    required this.entries,
    required this.selection,
    required this.isDiff,
  }) : super(key: key);

  final List<StatsByPathEntry> entries;
  final ValueNotifier<StatsByPathEntry?> selection;
  final bool isDiff;

  static final _columnStore = <String, _RetainingPathTableColumns>{};
  static _RetainingPathTableColumns _columns(
    String dataKey,
    bool isDiff,
  ) =>
      _columnStore.putIfAbsent(
        dataKey,
        () => _RetainingPathTableColumns(isDiff),
      );

  @override
  Widget build(BuildContext context) {
    final dataKey = 'RetainingPathTable-${identityHashCode(entries)}';
    final columns = _columns(dataKey, isDiff);
    return FlatTable<StatsByPathEntry>(
      dataKey: dataKey,
      columns: columns.columnList,
      data: entries,
      keyFactory: (e) => Key(e.key.asLongString()),
      selectionNotifier: selection,
      defaultSortColumn: columns.shallowSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
