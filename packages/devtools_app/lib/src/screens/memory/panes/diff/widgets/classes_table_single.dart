// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/globals.dart';
import '../../../../../shared/memory/classes.dart';
import '../../../../../shared/primitives/byte_utils.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../../../shared/widgets/class_filter.dart';
import '../../../shared/widgets/shared_memory_widgets.dart';
import '../controller/class_data.dart';
import 'instances.dart';

class _ClassNameColumn extends ColumnData<SingleClassData>
    implements
        ColumnRenderer<SingleClassData>,
        ColumnHeaderRenderer<SingleClassData> {
  _ClassNameColumn(this.data)
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(200.0),
          alignment: ColumnAlignment.left,
        );

  final ClassesTableSingleData data;

  @override
  String? getValue(SingleClassData data) => data.className.className;

  @override
  bool get supportsSorting => true;

  @override
  // We are removing the tooltip, because it is provided by [HeapClassView].
  String getTooltip(SingleClassData data) => '';

  @override
  Widget build(
    BuildContext context,
    SingleClassData data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return HeapClassView(
      theClass: data.className,
      showCopyButton: isRowSelected,
      copyGaItem: gac.MemoryEvent.diffClassSingleCopy,
      rootPackage: serviceConnection.serviceManager.rootInfoNow().package,
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

class _InstanceColumn extends ColumnData<SingleClassData>
    implements ColumnRenderer<SingleClassData> {
  _InstanceColumn(this.classData)
      : super(
          'Instances',
          titleTooltip: nonGcableInstancesColumnTooltip,
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  final ClassesTableSingleData classData;

  @override
  int getValue(SingleClassData data) => data.objects.instanceCount;

  @override
  bool get numeric => true;

  @override
  Widget? build(
    BuildContext context,
    SingleClassData data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return HeapInstanceTableCell(
      data.objects,
      classData.heap,
      data.className,
      isSelected: isRowSelected,
    );
  }
}

class _ShallowSizeColumn extends ColumnData<SingleClassData> {
  _ShallowSizeColumn()
      : super(
          'Shallow Dart Size',
          titleTooltip: SizeType.shallow.description,
          fixedWidthPx: scaleByFontFactor(120.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(SingleClassData data) => data.objects.shallowSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleClassData data) => prettyPrintBytes(
        getValue(data),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<SingleClassData> {
  _RetainedSizeColumn(this.classData)
      : super(
          'Retained Dart Size',
          titleTooltip: SizeType.retained.description,
          fixedWidthPx: scaleByFontFactor(130.0),
          alignment: ColumnAlignment.right,
        );

  final ClassesTableSingleData classData;

  @override
  int getValue(SingleClassData data) => data.objects.retainedSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleClassData data) {
    final value = getValue(data);

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

  late final columnList = <ColumnData<SingleClassData>>[
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

  final ClassDataList<SingleClassData> classes;

  final ClassesTableSingleData classesData;

  final _ClassesTableSingleColumns _columns;

  @override
  Widget build(BuildContext context) {
    // We want to preserve the sorting and sort directions for ClassesTableDiff
    // no matter what the data passed to it is.
    const dataKey = 'ClassesTableSingle';

    return FlatTable<SingleClassData>(
      columns: _columns.columnList,
      data: classes.list,
      dataKey: dataKey,
      keyFactory: (e) => Key(e.className.fullName),
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
