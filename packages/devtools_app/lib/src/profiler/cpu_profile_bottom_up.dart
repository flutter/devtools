// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../globals.dart';
import '../table.dart';
import '../table_data.dart';
import '../utils.dart';
import 'cpu_profile_columns.dart';
import 'cpu_profile_model.dart';

/// A table of the CPU's bottom-up call tree.
class CpuBottomUpTable extends StatelessWidget {
  factory CpuBottomUpTable(List<CpuStackFrame> bottomUpRoots, {Key key}) {
    final treeColumn = MethodNameColumn();
    final startingSortColumn = SelfTimeColumn();
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      TotalTimeColumn(),
      startingSortColumn,
      treeColumn,
      // TODO(kenz): add source column for flutter apps once
      // https://github.com/dart-lang/sdk/issues/37553 is fixed.
      if (serviceManager.connectedApp.isDartCliAppNow) SourceColumn(),
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
