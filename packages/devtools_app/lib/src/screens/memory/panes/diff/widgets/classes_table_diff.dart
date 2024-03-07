// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/memory/classes.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/table/table_data.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../../../shared/widgets/class_filter.dart';
import '../../../shared/widgets/shared_memory_widgets.dart';
import '../controller/class_data.dart';
import '../data/classes_diff.dart';
import 'instances.dart';

enum _DataPart {
  created,
  deleted,
  delta,
  persisted,
}

class _ClassNameColumn extends ColumnData<DiffClassData>
    implements
        ColumnRenderer<DiffClassData>,
        ColumnHeaderRenderer<DiffClassData> {
  _ClassNameColumn(this.diffData)
      : super(
          'Class',
          titleTooltip: 'Class name',
          fixedWidthPx: scaleByFontFactor(200.0),
          alignment: ColumnAlignment.left,
        );

  final ClassesTableDiffData diffData;

  @override
  String? getValue(DiffClassData dataObject) => dataObject.className.className;

  @override
  bool get supportsSorting => true;

  @override
  // We are removing the tooltip, because it is provided by [HeapClassView].
  String getTooltip(DiffClassData dataObject) => '';

  @override
  Widget build(
    BuildContext context,
    DiffClassData data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return HeapClassView(
      theClass: data.className,
      showCopyButton: isRowSelected,
      copyGaItem: gac.MemoryEvent.diffClassDiffCopy,
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
        ClassFilterButton(diffData.filterData),
      ],
    );
  }
}

class _InstanceColumn extends ColumnData<DiffClassData>
    implements ColumnRenderer<DiffClassData> {
  _InstanceColumn(this.dataPart, this.diffData)
      : super(
          columnTitle(dataPart),
          fixedWidthPx: scaleByFontFactor(110.0),
          alignment: ColumnAlignment.right,
        );

  final _DataPart dataPart;

  final ClassesTableDiffData diffData;

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
  int getValue(DiffClassData dataObject) =>
      _instances(dataObject).instanceCount;

  ObjectSetStats _instances(DiffClassData classData) {
    switch (dataPart) {
      case _DataPart.created:
        return classData.diff.created;
      case _DataPart.deleted:
        return classData.diff.deleted;
      case _DataPart.delta:
        return classData.diff.delta;
      case _DataPart.persisted:
        return classData.diff.persisted;
    }
  }

  @override
  String getDisplayValue(DiffClassData dataObject) {
    // Add leading sign for delta values.
    final value = getValue(dataObject);
    if (dataPart != _DataPart.delta || value <= 0) return value.toString();
    return '+$value';
  }

  @override
  bool get numeric => true;

  @override
  Widget? build(
    BuildContext context,
    DiffClassData data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    final objects = _instances(data);

    if (dataPart == _DataPart.delta) {
      assert(objects is! ObjectSet);
      return null;
    }

    final heapCallback = dataPart == _DataPart.deleted
        ? diffData.heapBefore
        : diffData.heapAfter;

    if (objects is! ObjectSet) {
      throw StateError(
        'All columns except ${_DataPart.delta} should have objects available.',
      );
    }

    return HeapInstanceTableCell(
      objects,
      heapCallback,
      data.className,
      isSelected: isRowSelected,
      liveItemsEnabled: dataPart != _DataPart.deleted,
    );
  }
}

class _SizeColumn extends ColumnData<DiffClassData> {
  _SizeColumn(this.dataPart, this.sizeType)
      : super(
          columnTitle(dataPart),
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  final _DataPart dataPart;
  final SizeType sizeType;

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
  int getValue(DiffClassData data) {
    switch (sizeType) {
      case SizeType.shallow:
        switch (dataPart) {
          case _DataPart.created:
            return data.diff.created.shallowSize;
          case _DataPart.deleted:
            return data.diff.deleted.shallowSize;
          case _DataPart.delta:
            return data.diff.delta.shallowSize;
          case _DataPart.persisted:
            return data.diff.persisted.shallowSize;
        }
      case SizeType.retained:
        switch (dataPart) {
          case _DataPart.created:
            return data.diff.created.retainedSize;
          case _DataPart.deleted:
            return data.diff.deleted.retainedSize;
          case _DataPart.delta:
            return data.diff.delta.retainedSize;
          case _DataPart.persisted:
            return data.diff.persisted.retainedSize;
        }
    }
  }

  @override
  String getDisplayValue(DiffClassData data) {
    // Add leading sign for delta values.
    final value = getValue(data);
    final asSize = prettyPrintRetainedSize(value)!;
    if (dataPart != _DataPart.delta || value <= 0) return asSize;
    return '+$asSize';
  }

  @override
  bool get numeric => true;
}

class ClassesTableDiffColumns {
  ClassesTableDiffColumns(this.sizeType, this.diffData);

  final SizeType sizeType;
  final ClassesTableDiffData diffData;

  late final sizeDeltaColumn = _SizeColumn(_DataPart.delta, sizeType);

  late final List<ColumnData<DiffClassData>> columnList =
      <ColumnData<DiffClassData>>[
    _ClassNameColumn(diffData),
    _InstanceColumn(_DataPart.created, diffData),
    _InstanceColumn(_DataPart.deleted, diffData),
    _InstanceColumn(_DataPart.delta, diffData),
    _InstanceColumn(_DataPart.persisted, diffData),
    _SizeColumn(_DataPart.created, sizeType),
    _SizeColumn(_DataPart.deleted, sizeType),
    sizeDeltaColumn,
    _SizeColumn(_DataPart.persisted, sizeType),
  ];
}

class _SizeGroupTitle extends StatelessWidget {
  const _SizeGroupTitle(this.diffData);

  final ClassesTableDiffData diffData;

  @override
  Widget build(BuildContext context) {
    final sizeType = diffData.selectedSizeType.value;

    return maybeWrapWithTooltip(
      child: Padding(
        padding: const EdgeInsets.all(densePadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundedDropDownButton<SizeType>(
              isDense: true,
              value: sizeType,
              onChanged: (SizeType? value) =>
                  diffData.selectedSizeType.value = value!,
              items: SizeType.values
                  .map(
                    (sizeType) => DropdownMenuItem<SizeType>(
                      value: sizeType,
                      child: Text(sizeType.displayName),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(width: denseSpacing),
            const Text('Size'),
          ],
        ),
      ),
      tooltip: '${sizeType.displayName} size:\n${sizeType.description}',
    );
  }
}

class ClassesTableDiff extends StatelessWidget {
  ClassesTableDiff({
    Key? key,
    required this.classes,
    required this.diffData,
  }) : super(key: key) {
    _columns = {
      for (var sizeType in SizeType.values)
        sizeType: ClassesTableDiffColumns(sizeType, diffData),
    };
  }

  final List<DiffClassData> classes;
  final ClassesTableDiffData diffData;

  List<ColumnGroup> _columnGroups() {
    return [
      ColumnGroup.fromText(
        title: '',
        range: const Range(0, 1),
      ),
      ColumnGroup.fromText(
        title: 'Instances',
        range: const Range(1, 5),
        tooltip: nonGcableInstancesColumnTooltip,
      ),
      ColumnGroup(
        title: _SizeGroupTitle(diffData),
        range: const Range(5, 9),
      ),
    ];
  }

  late final Map<SizeType, ClassesTableDiffColumns> _columns;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SizeType>(
      valueListenable: diffData.selectedSizeType,
      builder: (context, sizeType, _) {
        // We want to preserve the sorting and sort directions for ClassesTableDiff
        // no matter what the data passed to it is.
        const dataKey = 'ClassesTableDiff';

        final columns = _columns[sizeType]!;

        return FlatTable<DiffClassData>(
          columns: columns.columnList,
          columnGroups: _columnGroups(),
          data: classes,
          dataKey: dataKey,
          keyFactory: (e) => Key(e.className.fullName),
          selectionNotifier: diffData.selection,
          onItemSelected: (_) => ga.select(
            gac.memory,
            gac.MemoryEvent.diffClassDiffSelect,
          ),
          defaultSortColumn: columns.sizeDeltaColumn,
          defaultSortDirection: SortDirection.descending,
        );
      },
    );
  }
}
