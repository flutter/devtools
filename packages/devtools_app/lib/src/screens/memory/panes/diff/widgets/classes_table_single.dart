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
import '../../../shared/heap/primitives.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

class _ClassNameColumn extends ColumnData<SingleClassStats> {
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
  String getTooltip(SingleClassStats classStats) =>
      classStats.heapClass.fullName;
}

class _InstanceColumn extends ColumnData<SingleClassStats> {
  _InstanceColumn()
      : super(
          'Non GC-able\nInstances',
          titleTooltip: nonGcableInstancesColumnTooltip,
          fixedWidthPx: scaleByFontFactor(180.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(SingleClassStats classStats) => classStats.objects.instanceCount;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;
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
  bool get supportsSorting => true;

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
  _RetainedSizeColumn()
      : super(
          'Retained\nDart Size',
          titleTooltip: retainedSizeColumnTooltip,
          fixedWidthPx: scaleByFontFactor(85.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(SingleClassStats classStats) => classStats.objects.retainedSize;

  @override
  bool get supportsSorting => true;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(SingleClassStats classStats) => prettyPrintBytes(
        getValue(classStats),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class ClassesTableSingle extends StatefulWidget {
  const ClassesTableSingle({
    Key? key,
    required this.item,
    required this.controller,
  }) : super(key: key);

  final SnapshotInstanceItem item;

  final DiffPaneController controller;

  @override
  State<ClassesTableSingle> createState() => _ClassesTableSingleState();
}

class _ClassesTableSingleState extends State<ClassesTableSingle>
    with AutoDisposeMixin {
  late SingleHeapClasses _classes;
  final ColumnData<SingleClassStats> _shallowSizeColumn = _ShallowSizeColumn();
  late final List<ColumnData<SingleClassStats>> _columns =
      <ColumnData<SingleClassStats>>[
    _ClassNameColumn(),
    _InstanceColumn(),
    _shallowSizeColumn,
    _RetainedSizeColumn(),
  ];

  void _initWidget() {
    _classes = widget.item.classesToShow() as SingleHeapClasses;
  }

  @override
  void initState() {
    super.initState();
    _initWidget();
  }

  @override
  void didUpdateWidget(covariant ClassesTableSingle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item != oldWidget.item) _initWidget();
  }

  @override
  Widget build(BuildContext context) {
    return FlatTable<SingleClassStats>(
      columns: _columns,
      data: _classes.classes,
      dataKey: widget.item.id.toString(),
      keyFactory: (e) => Key(e.heapClass.fullName),
      onItemSelected: (r) => widget.controller.setSelectedClass(r?.heapClass),
      // TODO: figure out casting.
      selectionNotifier: widget.item.selectedSingleClassStats
          as ValueNotifier<SingleClassStats?>,
      defaultSortColumn: _shallowSizeColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
