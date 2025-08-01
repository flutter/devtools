// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../../shared/primitives/utils.dart';
import '../../../shared/table/table.dart';
import '../../../shared/table/table_data.dart';
import '../cpu_profile_model.dart';
import 'cpu_profile_columns.dart';

/// A table of the CPU's top-down call tree.
class CpuCallTreeTable extends StatelessWidget {
  const CpuCallTreeTable({required this.dataRoots, super.key});

  static const methodColumn = MethodAndSourceColumn();

  static final selfTimeColumn = SelfTimeColumn(titleTooltip: selfTimeTooltip);

  static final totalTimeColumn = TotalTimeColumn(
    titleTooltip: totalTimeTooltip,
  );

  static final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
    totalTimeColumn,
    selfTimeColumn,
    methodColumn,
  ]);

  static const totalTimeTooltip =
      'Time that a method spent executing its own code\nas well as the code for '
      'any methods it called.';

  static const selfTimeTooltip =
      'Time that a method spent executing only its own code.';

  final List<CpuStackFrame> dataRoots;

  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      dataRoots: dataRoots,
      dataKey: 'cpu-call-tree',
      columns: columns,
      treeColumn: methodColumn,
      defaultSortColumn: totalTimeColumn,
      displayTreeGuidelines: true,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
