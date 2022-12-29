// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/theme.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/primitives/instance_set_view.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../../../shared/shared_memory_widgets.dart';

class _ClassNameColumn extends ColumnData<SingleClassStats>
    implements ColumnRenderer<SingleClassStats> {
  _ClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(180.0),
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(SingleClassStats classStats) =>
      classStats.heapClass.className;

  @override
  bool get supportsSorting => true;

  @override
  // We are removing the tooltip, because it is provided by [HeapClassView].
  String getTooltip(SingleClassStats classStats) => '';

  @override
  Widget build(
    BuildContext context,
    SingleClassStats data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return HeapClassView(
      theClass: data.heapClass,
      showCopyButton: isRowSelected,
      copyGaItem: gac.MemoryEvent.diffClassSingleCopy,
      textStyle:
          isRowSelected ? theme.selectedTextStyle : theme.regularTextStyle,
    );
  }
}

class _InstanceColumn extends ColumnData<SingleClassStats>
    implements ColumnRenderer<SingleClassStats> {
  _InstanceColumn()
      : super(
          'Instances',
          titleTooltip: nonGcableInstancesColumnTooltip,
          fixedWidthPx: scaleByFontFactor(180.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(SingleClassStats classStats) => classStats.objects.instanceCount;

  @override
  bool get numeric => true;

  @override
  Widget build(
    BuildContext context,
    SingleClassStats data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InstanceSetView(
          textStyle:
              isRowSelected ? theme.selectedTextStyle : theme.regularTextStyle,
          count: getValue(data),
          gaContext: gac.MemoryAreas.snapshotSingle,
          sampleObtainer: isRowSelected ? () => throw 'not implemented' : null,
          showMenu: isRowSelected,
        ),
      ],
    );
  }
}

class _ShallowSizeColumn extends ColumnData<SingleClassStats> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: shallowSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(SingleClassStats classStats) => classStats.objects.shallowSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleClassStats classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<SingleClassStats> {
  _RetainedSizeColumn(this.totalSize)
      : super(
          'Retained Dart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(140.0),
          alignment: ColumnAlignment.right,
        );

  final int totalSize;

  @override
  int getValue(SingleClassStats classStats) => classStats.objects.retainedSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleClassStats classStats) {
    final value = getValue(classStats);

    final bytes = prettyPrintBytes(
      value,
      includeUnit: true,
      kbFractionDigits: 1,
    )!;

    final percents = '${(value * 100 / totalSize).round()}%';

    return '$bytes ($percents)';
  }
}

class _ClassesTableSingleColumns {
  _ClassesTableSingleColumns(this.totalSize);

  final int totalSize;

  late final retainedSizeColumn = _RetainedSizeColumn(totalSize);

  late final columnList = <ColumnData<SingleClassStats>>[
    _ClassNameColumn(),
    _InstanceColumn(),
    _ShallowSizeColumn(),
    retainedSizeColumn,
  ];
}

class ClassesTableSingle extends StatelessWidget {
  const ClassesTableSingle({
    super.key,
    required this.classes,
    required this.selection,
    required this.totalSize,
  });

  final int totalSize;

  final List<SingleClassStats> classes;
  final ValueNotifier<SingleClassStats?> selection;

  static final _columnStore = <String, _ClassesTableSingleColumns>{};
  static _ClassesTableSingleColumns _columns(int totalSize) =>
      _columnStore.putIfAbsent(
        '$totalSize',
        () => _ClassesTableSingleColumns(totalSize),
      );

  @override
  Widget build(BuildContext context) {
    // We want to preserve the sorting and sort directions for ClassesTableDiff
    // no matter what the data passed to it is.
    const dataKey = 'ClassesTableSingle';
    return FlatTable<SingleClassStats>(
      columns: _columns(totalSize).columnList,
      data: classes,
      dataKey: dataKey,
      keyFactory: (e) => Key(e.heapClass.fullName),
      selectionNotifier: selection,
      onItemSelected: (_) => ga.select(
        gac.memory,
        gac.MemoryEvent.diffClassSingleSelect,
      ),
      defaultSortColumn: _columns(totalSize).retainedSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
