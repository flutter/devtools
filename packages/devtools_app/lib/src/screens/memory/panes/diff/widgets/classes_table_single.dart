// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/feature_flags.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../../../shared/theme.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../../../shared/shared_memory_widgets.dart';
import 'instances.dart';

class SingleClassNameColumn extends ColumnData<SingleClassStats>
    implements
        ColumnRenderer<SingleClassStats>,
        ColumnHeaderRenderer<SingleClassStats> {
  SingleClassNameColumn()
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(200.0),
          alignment: ColumnAlignment.left,
        );

  static late Widget classFilterButton;

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
        classFilterButton,
      ],
    );
  }
}

class SingleInstanceColumn extends ColumnData<SingleClassStats>
    implements ColumnRenderer<SingleClassStats> {
  SingleInstanceColumn()
      : super(
          'Instances',
          titleTooltip: nonGcableInstancesColumnTooltip,
          fixedWidthPx: scaleByFontFactor(180.0),
          alignment: ColumnAlignment.right,
        );

  static late HeapDataObtainer heapOpbtainer;

  @override
  int getValue(SingleClassStats classStats) => classStats.objects.instanceCount;

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
      heapOpbtainer,
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

class SingleRetainedSizeColumn extends ColumnData<SingleClassStats> {
  SingleRetainedSizeColumn()
      : super(
          'Retained Dart Size',
          titleTooltip: SizeType.retained.description,
          fixedWidthPx: scaleByFontFactor(140.0),
          alignment: ColumnAlignment.right,
        );

  static late final HeapSizeObtainer totalSizeObtainer;

  @override
  int getValue(SingleClassStats dataObject) => dataObject.objects.retainedSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleClassStats dataObject) {
    final value = getValue(dataObject);

    final bytes = prettyPrintRetainedSize(value)!;

    final percents = '${(value * 100 / totalSizeObtainer()).round()}%';

    return '$bytes ($percents)';
  }
}

class _ClassesTableSingleColumns {
  _ClassesTableSingleColumns();

  late final retainedSizeColumn = SingleRetainedSizeColumn();

  late final columnList = <ColumnData<SingleClassStats>>[
    SingleClassNameColumn(),
    SingleInstanceColumn(),
    _ShallowSizeColumn(),
    retainedSizeColumn,
  ];
}

typedef HeapSizeObtainer = int Function();

class ClassesTableSingle extends StatelessWidget {
  const ClassesTableSingle({
    super.key,
    required this.classes,
    required this.selection,
  });

  final List<SingleClassStats> classes;

  final ValueNotifier<SingleClassStats?> selection;

  static final columns = _ClassesTableSingleColumns();

  @override
  Widget build(BuildContext context) {
    // We want to preserve the sorting and sort directions for ClassesTableDiff
    // no matter what the data passed to it is.
    const dataKey = 'ClassesTableSingle';

    return FlatTable<SingleClassStats>(
      columns: columns.columnList,
      data: classes,
      dataKey: dataKey,
      keyFactory: (e) => Key(e.heapClass.fullName),
      selectionNotifier: selection,
      onItemSelected: (_) => ga.select(
        gac.memory,
        gac.MemoryEvent.diffClassSingleSelect,
      ),
      defaultSortColumn: columns.retainedSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
