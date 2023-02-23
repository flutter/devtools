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
import '../controller/heap_diff.dart';
import 'instances.dart';

enum _DataPart {
  created,
  deleted,
  delta,
  persisted,
}

enum _SizeType {
  shallow,
  retained,
}

class _ClassNameColumn extends ColumnData<DiffClassStats>
    implements
        ColumnRenderer<DiffClassStats>,
        ColumnHeaderRenderer<DiffClassStats> {
  _ClassNameColumn(this.classFilterButton)
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(200.0),
          alignment: ColumnAlignment.left,
        );

  final Widget classFilterButton;

  @override
  String? getValue(DiffClassStats classStats) => classStats.heapClass.className;

  @override
  bool get supportsSorting => true;

  @override
  // We are removing the tooltip, because it is provided by [HeapClassView].
  String getTooltip(DiffClassStats classStats) => '';

  @override
  Widget build(
    BuildContext context,
    DiffClassStats data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return HeapClassView(
      theClass: data.heapClass,
      showCopyButton: isRowSelected,
      copyGaItem: gac.MemoryEvent.diffClassDiffCopy,
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

class _InstanceColumn extends ColumnData<DiffClassStats>
    implements ColumnRenderer<DiffClassStats> {
  _InstanceColumn(this.dataPart, this.heap)
      : super(
          columnTitle(dataPart),
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  final _DataPart dataPart;

  final AdaptedHeapData? heap;

  static String columnTitle(_DataPart dataPart) {
    switch (dataPart) {
      case _DataPart.created:
        return 'New';
      case _DataPart.deleted:
        return 'Released';
      case _DataPart.delta:
        return 'Delta';
      case _DataPart.persisted:
        return 'Persisted';
    }
  }

  @override
  int getValue(DiffClassStats classStats) =>
      _instances(classStats).instanceCount;

  ObjectSetStats _instances(DiffClassStats classStats) {
    switch (dataPart) {
      case _DataPart.created:
        return classStats.total.created;
      case _DataPart.deleted:
        return classStats.total.deleted;
      case _DataPart.delta:
        return classStats.total.delta;
      case _DataPart.persisted:
        return classStats.total.persisted;
    }
  }

  @override
  String getDisplayValue(DiffClassStats classStats) {
    // Add leading sign for delta values.
    final value = getValue(classStats);
    if (dataPart != _DataPart.delta || value <= 0) return value.toString();
    return '+$value';
  }

  @override
  bool get numeric => true;

  @override
  Widget? build(
    BuildContext context,
    DiffClassStats data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    if (!FeatureFlags.evalAndBrowse) return null;
    final objects = _instances(data);
    final theHeap = heap;

    if (dataPart == _DataPart.delta) {
      assert(theHeap == null);
      assert(objects is! ObjectSet);
      return null;
    }

    if (objects is! ObjectSet || theHeap == null) {
      throw StateError(
        'All columns except ${_DataPart.delta} should have objects and heap data available.',
      );
    }

    return InstanceTableCell(
      objects,
      theHeap,
      data.heapClass,
      isSelected: isRowSelected,
      gaContext: gac.MemoryAreas.snapshotDiff,
    );
  }
}

class _SizeColumn extends ColumnData<DiffClassStats> {
  _SizeColumn(this.dataPart, this.sizeType)
      : super(
          columnTitle(dataPart),
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  final _DataPart dataPart;
  final _SizeType sizeType;

  static String columnTitle(_DataPart dataPart) {
    switch (dataPart) {
      case _DataPart.created:
        return 'Allocated';
      case _DataPart.deleted:
        return 'Freed';
      case _DataPart.delta:
        return 'Delta';
      case _DataPart.persisted:
        return 'Persisted';
    }
  }

  @override
  int getValue(DiffClassStats classStats) {
    switch (sizeType) {
      case _SizeType.shallow:
        switch (dataPart) {
          case _DataPart.created:
            return classStats.total.created.shallowSize;
          case _DataPart.deleted:
            return classStats.total.deleted.shallowSize;
          case _DataPart.delta:
            return classStats.total.delta.shallowSize;
          case _DataPart.persisted:
            return classStats.total.persisted.shallowSize;
        }
      case _SizeType.retained:
        switch (dataPart) {
          case _DataPart.created:
            return classStats.total.created.retainedSize;
          case _DataPart.deleted:
            return classStats.total.deleted.retainedSize;
          case _DataPart.delta:
            return classStats.total.delta.retainedSize;
          case _DataPart.persisted:
            return classStats.total.persisted.retainedSize;
        }
    }
  }

  @override
  String getDisplayValue(DiffClassStats classStats) {
    // Add leading sign for delta values.
    final value = getValue(classStats);
    final asSize = prettyPrintRetainedSize(value)!;
    if (dataPart != _DataPart.delta || value <= 0) return asSize;
    return '+$asSize';
  }

  @override
  bool get numeric => true;
}

class _ClassesTableDiffColumns {
  _ClassesTableDiffColumns(
    this.classFilterButton, {
    required this.before,
    required this.after,
  });

  final Widget classFilterButton;

  final retainedSizeDeltaColumn =
      _SizeColumn(_DataPart.delta, _SizeType.retained);

  final AdaptedHeapData before;
  final AdaptedHeapData after;

  late final List<ColumnData<DiffClassStats>> columnList =
      <ColumnData<DiffClassStats>>[
    _ClassNameColumn(classFilterButton),
    _InstanceColumn(_DataPart.created, after),
    _InstanceColumn(_DataPart.deleted, before),
    _InstanceColumn(_DataPart.delta, null),
    _InstanceColumn(_DataPart.persisted, after),
    _SizeColumn(_DataPart.created, _SizeType.shallow),
    _SizeColumn(_DataPart.deleted, _SizeType.shallow),
    _SizeColumn(_DataPart.delta, _SizeType.shallow),
    _SizeColumn(_DataPart.persisted, _SizeType.shallow),
    _SizeColumn(_DataPart.created, _SizeType.retained),
    _SizeColumn(_DataPart.deleted, _SizeType.retained),
    retainedSizeDeltaColumn,
    _SizeColumn(_DataPart.persisted, _SizeType.retained),
  ];
}

class ClassesTableDiff extends StatelessWidget {
  const ClassesTableDiff({
    Key? key,
    required this.classes,
    required this.selection,
    required this.classFilterButton,
    required this.before,
    required this.after,
  }) : super(key: key);

  final List<DiffClassStats> classes;
  final ValueNotifier<DiffClassStats?> selection;
  final AdaptedHeapData before;
  final AdaptedHeapData after;

  static final _columnGroups = [
    ColumnGroup.fromText(
      title: '',
      range: const Range(0, 1),
    ),
    ColumnGroup.fromText(
      title: 'Instances',
      range: const Range(1, 5),
      tooltip: nonGcableInstancesColumnTooltip,
    ),
    ColumnGroup.fromText(
      title: 'Shallow Dart Size',
      range: const Range(5, 9),
      tooltip: shallowSizeColumnTooltip,
    ),
    ColumnGroup.fromText(
      title: 'Retained Dart Size',
      range: const Range(9, 13),
      tooltip: retainedSizeColumnTooltip,
    ),
  ];

  final Widget classFilterButton;

  @override
  Widget build(BuildContext context) {
    // We want to preserve the sorting and sort directions for ClassesTableDiff
    // no matter what the data passed to it is.
    const dataKey = 'ClassesTableDiff';
    final columns = _ClassesTableDiffColumns(
      classFilterButton,
      before: before,
      after: after,
    );
    return FlatTable<DiffClassStats>(
      columns: columns.columnList,
      columnGroups: _columnGroups,
      data: classes,
      dataKey: dataKey,
      keyFactory: (e) => Key(e.heapClass.fullName),
      selectionNotifier: selection,
      onItemSelected: (_) => ga.select(
        gac.memory,
        gac.MemoryEvent.diffClassDiffSelect,
      ),
      defaultSortColumn: columns.retainedSizeDeltaColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
