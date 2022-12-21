// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import 'cpu_profile_columns.dart';
import 'cpu_profile_model.dart';

/// A table of the CPU's top-down call tree.
class CpuCallTreeTable extends StatelessWidget {
  factory CpuCallTreeTable(
    List<CpuStackFrame> dataRoots, {
    Key? key,
    required bool displayTreeGuidelines,
  }) {
    final treeColumn = MethodNameColumn();
    final startingSortColumn = TotalTimeColumn(titleTooltip: totalTimeTooltip);
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      startingSortColumn,
      SelfTimeColumn(titleTooltip: selfTimeTooltip),
      treeColumn,
      SourceColumn(),
    ]);
    return CpuCallTreeTable._(
      key,
      dataRoots,
      treeColumn,
      startingSortColumn,
      columns,
      displayTreeGuidelines,
    );
  }

  const CpuCallTreeTable._(
    Key? key,
    this.dataRoots,
    this.treeColumn,
    this.sortColumn,
    this.columns,
    this.displayTreeGuidelines,
  ) : super(key: key);

  static const totalTimeTooltip =
      'Time that a method spent executing its own code\nas well as the code for '
      'any methods it called.';

  static const selfTimeTooltip =
      'Time that a method spent executing only its own code.';

  final TreeColumnData<CpuStackFrame> treeColumn;
  final ColumnData<CpuStackFrame> sortColumn;
  final List<ColumnData<CpuStackFrame>> columns;
  final List<CpuStackFrame> dataRoots;
  final bool displayTreeGuidelines;

  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      dataRoots: dataRoots,
      dataKey: 'cpu-call-tree',
      columns: columns,
      treeColumn: treeColumn,
      defaultSortColumn: sortColumn,
      displayTreeGuidelines: displayTreeGuidelines,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
