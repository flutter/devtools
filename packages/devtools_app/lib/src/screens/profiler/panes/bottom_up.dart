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

/// A table of the CPU's bottom-up call tree.
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
          _bottomUpTimeTooltipBuilder('Self', stackFrame, context),
    );
    final totalTimeColumn = TotalTimeColumn(
      titleTooltip: totalTimeTooltip,
      dataTooltipProvider: (stackFrame, context) =>
          _bottomUpTimeTooltipBuilder('Total', stackFrame, context),
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

  static const totalTimeTooltip =
      'Time that a method spent executing its own code as well as the code for '
      'the\nmethod that it called (which is displayed as an ancestor in the '
      'bottom up tree).';

  static const selfTimeTooltip =
      'For top-level methods in the bottom-up tree (stack frames that were at '
      'the top of at least one CPU sample), this is the time the method spent '
      'executing only its own code.\mFor children methods in the bottom-up '
      'tree (the callers), this is the self time of the top-level method (the '
      'callee) when called through the child method (the caller).';

  static InlineSpan? _bottomUpTimeTooltipBuilder(
    String type,
    CpuStackFrame stackFrame,
    BuildContext context,
  ) {
    // TODO(kenz): consider adding a tooltip for root nodes as well if this is
    // a point of confusion for the user.
    if (stackFrame.isRoot) {
      return null;
    }
    final fixedStyle = Theme.of(context).tooltipFixedFontStyle;
    return TextSpan(
      children: [
        TextSpan(text: '$type time for '),
        TextSpan(
          text: '${stackFrame.root.name}\n',
          style: fixedStyle,
        ),
        const TextSpan(text: 'when called through '),
        TextSpan(
          text: '${stackFrame.name}',
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
