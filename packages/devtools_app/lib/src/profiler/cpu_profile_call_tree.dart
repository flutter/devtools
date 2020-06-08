// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../table.dart';
import '../table_data.dart';
import '../utils.dart';
import 'cpu_profile_columns.dart';
import 'cpu_profile_model.dart';

/// A table of the CPU's top-down call tree.
class CpuCallTreeTable extends StatelessWidget {
  factory CpuCallTreeTable(CpuProfileData data, {Key key}) {
    final treeColumn = MethodNameColumn();
    final startingSortColumn = TotalTimeColumn();
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      startingSortColumn,
      SelfTimeColumn(),
      treeColumn,
      SourceColumn(),
    ]);
    return CpuCallTreeTable._(
      key,
      data,
      treeColumn,
      startingSortColumn,
      columns,
    );
  }

  const CpuCallTreeTable._(
    Key key,
    this.data,
    this.treeColumn,
    this.sortColumn,
    this.columns,
  ) : super(key: key);

  final TreeColumnData<CpuStackFrame> treeColumn;
  final ColumnData<CpuStackFrame> sortColumn;
  final List<ColumnData<CpuStackFrame>> columns;

  final CpuProfileData data;
  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      dataRoots: [data.cpuProfileRoot.deepCopy()],
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      sortColumn: sortColumn,
      sortDirection: SortDirection.descending,
    );
  }
}
