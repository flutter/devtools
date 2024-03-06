// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../../shared/memory/classes.dart';
import '../../../../../../shared/primitives/utils.dart';
import '../../../../../../shared/table/table.dart';
import '../../../../../../shared/table/table_data.dart';
import '../../../../shared/primitives/simple_elements.dart';
import '../../controller/class.dart';

class _RetainingPathColumn extends ColumnData<PathData> {
  _RetainingPathColumn(String className)
      : super.wide(
          'Shortest Retaining Path for Instances of $className',
          titleTooltip: 'The shortest sequence of objects\n'
              'retaining $className instances from garbage collection.',
          alignment: ColumnAlignment.left,
        );

  @override
  String? getValue(PathData record) =>
      record.path.toShortString(inverted: true);

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(PathData record) => '';
}

class _InstanceColumn extends ColumnData<PathData> {
  _InstanceColumn(bool isDiff)
      : super(
          isDiff ? 'Instance\nDelta' : 'Instances',
          titleTooltip: 'Number of instances of the class\n'
              'retained by the path.',
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(PathData record) => record.objects.instanceCount;

  @override
  bool get numeric => true;
}

class _ShallowSizeColumn extends ColumnData<PathData> {
  _ShallowSizeColumn(bool isDiff)
      : super(
          isDiff ? 'Shallow\nSize Delta' : 'Shallow\nDart Size',
          titleTooltip: SizeType.shallow.description,
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(PathData record) => record.objects.shallowSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(PathData record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainedSizeColumn extends ColumnData<PathData> {
  _RetainedSizeColumn(bool isDiff)
      : super(
          isDiff ? 'Retained\nSize Delta' : 'Retained\nDart Size',
          titleTooltip: SizeType.retained.description,
          fixedWidthPx: scaleByFontFactor(80.0),
          alignment: ColumnAlignment.right,
        );

  @override
  int getValue(PathData record) => record.objects.retainedSize;

  @override
  bool get numeric => true;

  @override
  String getDisplayValue(PathData record) => prettyPrintBytes(
        getValue(record),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;
}

class _RetainingPathTableColumns {
  _RetainingPathTableColumns(this.isDiff, this.className);

  final bool isDiff;

  final String className;

  late final retainedSizeColumn = _RetainedSizeColumn(isDiff);

  late final columnList = <ColumnData<PathData>>[
    _RetainingPathColumn(className),
    _InstanceColumn(isDiff),
    _ShallowSizeColumn(isDiff),
    retainedSizeColumn,
  ];
}

class RetainingPathTable extends StatelessWidget {
  RetainingPathTable({
    Key? key,
    required this.classData,
    required this.selection,
    required this.isDiff,
  }) : super(key: key);

  final ValueNotifier<PathData?> selection;
  final bool isDiff;
  final ClassData classData;

  late final _data =
      classData.byPath.keys.map((path) => PathData(classData, path)).toList();

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
    final dataKey =
        'RetainingPathTable-$isDiff-${classData.heapClass.fullName}';
    final columns = _columns(dataKey, isDiff, classData.heapClass.shortName);
    return FlatTable<PathData>(
      dataKey: dataKey,
      columns: columns.columnList,
      data: _data,
      keyFactory: (e) => ValueKey(e.path),
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

// class RetainingPathTable_ extends StatelessWidget {
//   const RetainingPathTable_({
//     Key? key,
//     required this.entries,
//     required this.selection,
//     required this.isDiff,
//     required this.className,
//   }) : super(key: key);

//   final List<StatsByPathEntry> entries;
//   final ValueNotifier<StatsByPathEntry?> selection;
//   final bool isDiff;
//   final String className;

//   static final _columnStore = <String, _RetainingPathTableColumns>{};
//   static _RetainingPathTableColumns _columns(
//     String dataKey,
//     bool isDiff,
//     String className,
//   ) =>
//       _columnStore.putIfAbsent(
//         dataKey,
//         () => _RetainingPathTableColumns(isDiff, className),
//       );

//   @override
//   Widget build(BuildContext context) {
//     final dataKey = 'RetainingPathTable-$isDiff-$className';
//     final columns = _columns(dataKey, isDiff, className);
//     return FlatTable<PathData>(
//       dataKey: dataKey,
//       columns: columns.columnList,
//       data: entries,
//       keyFactory: (e) => ValueKey(e.path),
//       selectionNotifier: selection,
//       onItemSelected: (_) => ga.select(
//         gac.memory,
//         '${gac.MemoryEvent.diffPathSelect}-${isDiff ? "diff" : "single"}',
//       ),
//       defaultSortColumn: columns.retainedSizeColumn,
//       defaultSortDirection: SortDirection.descending,
//       tallHeaders: true,
//     );
//   }
// }
