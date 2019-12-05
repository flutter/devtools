// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/table.dart';
import '../../profiler/cpu_profile_columns.dart';
import '../../profiler/cpu_profile_model.dart';
import '../../table_data.dart';

/// A table of the CPU's call tree.
class CpuCallTreeTable extends StatelessWidget {
  factory CpuCallTreeTable(CpuProfileData data, {Key key}) {
    final treeColumn = MethodNameColumn();
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      TotalTimeColumn(),
      SelfTimeColumn(),
      treeColumn,
      SourceColumn(),
    ]);
    return CpuCallTreeTable._(key, data, treeColumn, columns);
  }
  const CpuCallTreeTable._(Key key, this.data, this.treeColumn, this.columns)
      : super(key: key);

  final TreeColumnData<CpuStackFrame> treeColumn;
  final List<ColumnData<CpuStackFrame>> columns;

  final CpuProfileData data;
  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      data: data.cpuProfileRoot,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
    );
  }
}
