// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../shared/primitives/utils.dart';
import '../../../shared/table/table.dart';
import '../../../shared/table/table_data.dart';
import '../../../shared/theme.dart';
import '../cpu_profile_columns.dart';
import '../cpu_profile_model.dart';

/// A table of the bottom up tree for a CPU profile.
class CpuBottomUpTable extends StatelessWidget {
  factory CpuBottomUpTable(
    List<CpuStackFrame> bottomUpRoots, {
    Key? key,
    required bool displayTreeGuidelines,
  }) {
    final treeColumn = MethodAndSourceColumn();
    final selfTimeColumn = SelfTimeColumn(
      titleTooltip: selfTimeTooltip,
      dataTooltipProvider: (stackFrame, context) =>
          _bottomUpTimeTooltipBuilder(_TimeType.self, stackFrame, context),
    );
    final totalTimeColumn = TotalTimeColumn(
      titleTooltip: totalTimeTooltip,
      dataTooltipProvider: (stackFrame, context) =>
          _bottomUpTimeTooltipBuilder(_TimeType.total, stackFrame, context),
    );
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      totalTimeColumn,
      selfTimeColumn,
      treeColumn,
    ]);

    return CpuBottomUpTable._(
      key,
      bottomUpRoots,
      treeColumn,
      selfTimeColumn,
      columns,
      displayTreeGuidelines,
    );
  }

  const CpuBottomUpTable._(
    Key? key,
    this.bottomUpRoots,
    this.treeColumn,
    this.sortColumn,
    this.columns,
    this.displayTreeGuidelines,
  ) : super(key: key);

  final TreeColumnData<CpuStackFrame> treeColumn;
  final ColumnData<CpuStackFrame> sortColumn;
  final List<ColumnData<CpuStackFrame>> columns;
  final List<CpuStackFrame> bottomUpRoots;
  final bool displayTreeGuidelines;

  static const totalTimeTooltip = '''
For top-level methods in the bottom-up tree (stack frames that were at the top of at
least one CPU sample), this is the time the method spent executing its own code,
as well as the code for any methods that it called.

For children methods in the bottom-up tree (the callers), this is the total time of
the top-level method (the callee) when called through the child method (the caller).''';

  static const selfTimeTooltip = '''
For top-level methods in the bottom-up tree (stack frames that were at the top of at
least one CPU sample), this is the time the method spent executing only its own code.

For children methods in the bottom-up tree (the callers), this is the self time of
the top-level method (the callee) when called through the child method (the caller).''';

  static InlineSpan? _bottomUpTimeTooltipBuilder(
    _TimeType type,
    CpuStackFrame stackFrame,
    BuildContext context,
  ) {
    final fixedStyle = Theme.of(context).tooltipFixedFontStyle;
    if (stackFrame.isRoot) {
      switch (type) {
        case _TimeType.total:
          return TextSpan(
            children: [
              const TextSpan(text: 'Time that '),
              TextSpan(
                text: '[${stackFrame.name}]',
                style: fixedStyle,
              ),
              const TextSpan(
                text: ' spent executing its own code,\nas well as the code for'
                    ' any methods that it called.',
              ),
            ],
          );
        case _TimeType.self:
          return TextSpan(
            children: [
              const TextSpan(text: 'Time that '),
              TextSpan(
                text: '[${stackFrame.name}]',
                style: fixedStyle,
              ),
              const TextSpan(text: ' spent executing its own code.'),
            ],
          );
      }
    }
    return TextSpan(
      children: [
        TextSpan(text: '$type time for root '),
        TextSpan(
          text: '[${stackFrame.root.name}]',
          style: fixedStyle,
        ),
        const TextSpan(text: '\nwhen called through '),
        TextSpan(
          text: '[${stackFrame.name}]',
          style: fixedStyle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      displayTreeGuidelines: displayTreeGuidelines,
      dataRoots: bottomUpRoots,
      dataKey: 'cpu-bottom-up',
      columns: columns,
      treeColumn: treeColumn,
      defaultSortColumn: sortColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}

enum _TimeType {
  self,
  total;

  @override
  String toString() {
    switch (this) {
      case self:
        return 'Self';
      case total:
        return 'Total';
    }
  }
}
