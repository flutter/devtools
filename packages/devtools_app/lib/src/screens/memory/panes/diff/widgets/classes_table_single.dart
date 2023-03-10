// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/feature_flags.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/theme.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../../../shared/shared_memory_widgets.dart';
import '../controller/class_data.dart';
import 'class_filter.dart';
import 'instances.dart';

class _ClassNameColumn extends ColumnData<SingleClassStats>
    implements
        ColumnRenderer<SingleClassStats>,
        ColumnHeaderRenderer<SingleClassStats> {
  _ClassNameColumn(this.data)
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(200.0),
          alignment: ColumnAlignment.left,
        );

  final ClassesTableSingleData data;

  @override
  String? getValue(SingleClassStats dataObject) =>
      dataObject.heapClass.className;

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
      rootPackage: serviceManager.rootInfoNow().package,
    );
  }

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: defaultHeaderRenderer()),
        ClassFilterButton(data.filterData),
      ],
    );
  }
}

class _InstanceColumn extends ColumnData<SingleClassStats>
    implements ColumnRenderer<SingleClassStats> {
  _InstanceColumn(this.classData)
      : super(
          'Instances',
          titleTooltip: nonGcableInstancesColumnTooltip,
          fixedWidthPx: scaleByFontFactor(180.0),
          alignment: ColumnAlignment.right,
        );

  final ClassesTableSingleData classData;

  @override
  int getValue(SingleClassStats dataObject) => dataObject.objects.instanceCount;

  @override
  bool get numeric => true;

  @override
  Widget? build(
    BuildContext context,
    SingleClassStats data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    if (!FeatureFlags.evalAndBrowse) return null;

    return InstanceTableCell(
      data.objects,
      classData.heap,
      data.heapClass,
      isSelected: isRowSelected,
      gaContext: gac.MemoryAreas.snapshotSingle,
    );
  }
}

class _ShallowSizeColumn extends ColumnData<SingleClassStats> {
  _ShallowSizeColumn()
      : super(
          'Shallow\nDart Size',
          titleTooltip: SizeType.shallow.description,
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
  _RetainedSizeColumn(this.classData)
      : super(
          'Retained Dart Size',
          titleTooltip: SizeType.retained.description,
          fixedWidthPx: scaleByFontFactor(140.0),
          alignment: ColumnAlignment.right,
        );

  final ClassesTableSingleData classData;

  @override
  int getValue(SingleClassStats dataObject) => dataObject.objects.retainedSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleClassStats dataObject) {
    final value = getValue(dataObject);

    final bytes = prettyPrintRetainedSize(value)!;

    final percents =
        percent(value / classData.totalHeapSize(), fractionDigits: 0);

    return '$bytes ($percents)';
  }
}

class _ClassesTableSingleColumns {
  _ClassesTableSingleColumns(this.classData);

  late final retainedSizeColumn = _RetainedSizeColumn(classData);

  final ClassesTableSingleData classData;

  late final columnList = <ColumnData<SingleClassStats>>[
    _ClassNameColumn(classData),
    _InstanceColumn(classData),
    _ShallowSizeColumn(),
    retainedSizeColumn,
  ];
}

class ClassesTableSingle extends StatelessWidget {
  ClassesTableSingle({
    super.key,
    required this.classes,
    required this.classesData,
  }) : _columns = _ClassesTableSingleColumns(classesData);

  final List<SingleClassStats> classes;

  final ClassesTableSingleData classesData;

  final _ClassesTableSingleColumns _columns;

  @override
  Widget build(BuildContext context) {
    // We want to preserve the sorting and sort directions for ClassesTableDiff
    // no matter what the data passed to it is.
    const dataKey = 'ClassesTableSingle';

    return FlatTable<SingleClassStats>(
      columns: _columns.columnList,
      data: classes,
      dataKey: dataKey,
      keyFactory: (e) => Key(e.heapClass.fullName),
      selectionNotifier: classesData.selection,
      onItemSelected: (_) => ga.select(
        gac.memory,
        gac.MemoryEvent.diffClassSingleSelect,
      ),
      defaultSortColumn: _columns.retainedSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
