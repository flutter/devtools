// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:flutter/material.dart';

import '../../primitives/utils.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import 'cpu_profile_columns.dart';
import 'cpu_profile_model.dart';

/// A table of the CPU's bottom-up call tree.
class CpuBottomUpTable extends StatelessWidget {
  factory CpuBottomUpTable(List<CpuStackFrame> bottomUpRoots, {Key key}) {
    final treeColumn = MethodNameColumn();
    final startingSortColumn = SelfTimeColumn(titleTooltip: selfTimeTooltip);
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      TotalTimeColumn(titleTooltip: totalTimeTooltip),
      startingSortColumn,
      treeColumn,
      SourceColumn(),
    ]);
    return CpuBottomUpTable._(
      key,
      bottomUpRoots,
      treeColumn,
      startingSortColumn,
      columns,
    );
  }

  const CpuBottomUpTable._(
    Key key,
    this.bottomUpRoots,
    this.treeColumn,
    this.sortColumn,
    this.columns,
  ) : super(key: key);

  final TreeColumnData<CpuStackFrame> treeColumn;
  final ColumnData<CpuStackFrame> sortColumn;
  final List<ColumnData<CpuStackFrame>> columns;
  final List<CpuStackFrame> bottomUpRoots;

  static const totalTimeTooltip =
      'Time that a method spent executing its own code as well as the code for '
      'the\nmethod that it called (which is displayed as an ancestor in the '
      'bottom up tree).';

  static const selfTimeTooltip =
      'For top-level methods in the bottom-up tree (leaf stack frames in the '
      'CPU profile),\nthis is the time the method spent executing only its own '
      'code. For sub nodes (the\ncallers in the CPU profile), this is the self '
      'time of the callee when being called by\nthe caller. ';

  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      dataRoots: bottomUpRoots,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      sortColumn: sortColumn,
      sortDirection: SortDirection.descending,
    );
  }
}
