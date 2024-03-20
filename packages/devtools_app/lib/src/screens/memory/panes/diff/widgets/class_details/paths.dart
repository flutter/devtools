// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../../shared/primitives/byte_utils.dart';
import '../../../../../../shared/primitives/utils.dart';
import '../../../../../../shared/table/table.dart';
import '../../../../../../shared/table/table_data.dart';
import '../../../../shared/heap/heap.dart';
import '../../../../shared/primitives/simple_elements.dart';

class _RetainingPathColumn extends ColumnData<StatsByPathEntry> {
  _RetainingPathColumn(String className)
      : super.wide(
          'Shortest Retaining Path for Instances of $className',
          titleTooltip: 'The shortest sequence of objects\n'
              'retaining $className instances from garbage collection.',
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(StatsByPathEntry record) =>
      record.key.toShortString(inverted: true);

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(StatsByPathEntry record) => '';
}

class _InstanceColumn extends ColumnData<StatsByPathEntry> {
  _InstanceColumn(bool isDiff)
      : super(
          isDiff ? 'Instance\nDelta' : 'Instances',
          titleTooltip: 'Number of instances of the class\n'
              'retained by the path.',
          fixedWidthPx: scaleByFontFactor(80.0),
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
          titleTooltip: SizeType.shallow.description,
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(StatsByPathEntry record) => record.value.shallowSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(StatsByPathEntry record) =>
      prettyPrintBytes(getValue(record), includeUnit: true)!;
}

class _RetainedSizeColumn extends ColumnData<StatsByPathEntry> {
  _RetainedSizeColumn(bool isDiff)
      : super(
          isDiff ? 'Retained\nSize Delta' : 'Retained\nDart Size',
          titleTooltip: SizeType.retained.description,
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(StatsByPathEntry record) => record.value.retainedSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(StatsByPathEntry record) =>
      prettyPrintBytes(getValue(record), includeUnit: true)!;
}

class _RetainingPathTableColumns {
  _RetainingPathTableColumns(this.isDiff, this.className);

  final bool isDiff;

  final String className;

  late final retainedSizeColumn = _RetainedSizeColumn(isDiff);

  late final columnList = <ColumnData<StatsByPathEntry>>[
    _RetainingPathColumn(className),
    _InstanceColumn(isDiff),
    _ShallowSizeColumn(isDiff),
    retainedSizeColumn,
  ];
}

class RetainingPathTable extends StatelessWidget {
  const RetainingPathTable({
    Key? key,
    required this.entries,
    required this.selection,
    required this.isDiff,
    required this.className,
  }) : super(key: key);

  final List<StatsByPathEntry> entries;
  final ValueNotifier<StatsByPathEntry?> selection;
  final bool isDiff;
  final String className;

  static final _columnStore = <String, _RetainingPathTableColumns>{};
  static _RetainingPathTableColumns _columns(
    String dataKey,
    bool isDiff,
    String className,
  ) =>
      _columnStore.putIfAbsent(
        dataKey,
        () => _RetainingPathTableColumns(isDiff, className),
      );

  @override
  Widget build(BuildContext context) {
    final dataKey = 'RetainingPathTable-$isDiff-$className';
    final columns = _columns(dataKey, isDiff, className);
    return FlatTable<StatsByPathEntry>(
      dataKey: dataKey,
      columns: columns.columnList,
      data: entries,
      keyFactory: (e) => Key(e.key.toLongString()),
      selectionNotifier: selection,
      onItemSelected: (_) => ga.select(
        gac.memory,
        '${gac.MemoryEvent.diffPathSelect}-${isDiff ? "diff" : "single"}',
      ),
      defaultSortColumn: columns.retainedSizeColumn,
      defaultSortDirection: SortDirection.descending,
      tallHeaders: true,
    );
  }
}
