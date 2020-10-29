// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../globals.dart';
import '../table.dart';
import '../table_data.dart';
import '../utils.dart';
import 'cpu_profile_columns.dart';
import 'cpu_profile_model.dart';

/// A table of the CPU's top-down call tree.
class CpuCallTreeTable extends StatelessWidget {
  factory CpuCallTreeTable(List<CpuStackFrame> dataRoots, {Key key}) {
    final treeColumn = MethodNameColumn();
    final startingSortColumn = TotalTimeColumn();
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      startingSortColumn,
      SelfTimeColumn(),
      treeColumn,
      // TODO(kenz): add source column for flutter apps once
      // https://github.com/dart-lang/sdk/issues/37553 is fixed.
      if (serviceManager.connectedApp.isDartCliAppNow) SourceColumn(),
    ]);
    return CpuCallTreeTable._(
      key,
      dataRoots,
      treeColumn,
      startingSortColumn,
      columns,
    );
  }

  const CpuCallTreeTable._(
    Key key,
    this.dataRoots,
    this.treeColumn,
    this.sortColumn,
    this.columns,
  ) : super(key: key);

  final TreeColumnData<CpuStackFrame> treeColumn;
  final ColumnData<CpuStackFrame> sortColumn;
  final List<ColumnData<CpuStackFrame>> columns;
  final List<CpuStackFrame> dataRoots;

  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      dataRoots: dataRoots,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      sortColumn: sortColumn,
      sortDirection: SortDirection.descending,
    );
  }
}
