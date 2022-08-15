// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/table.dart';
import '../../../../shared/table_data.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../../profiler/cpu_profile_columns.dart';
import '../../../profiler/cpu_profile_model.dart';
import 'allocation_profile_tracing_view_controller.dart';

const double _countColumnWidth = 130;

/// Displays an allocation profile as a tree of stack frames, displaying
/// inclusive and exclusive allocation counts.
class AllocationTracingTree extends StatelessWidget {
  const AllocationTracingTree({required this.controller});

  final AllocationProfileTracingViewController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TracedClass?>(
      valueListenable: controller.selectedTracedClass,
      builder: (context, selection, _) {
        if (selection == null) {
          return const _AllocationTracingInstructions();
        } else if (!selection.traceAllocations) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Allocation tracing is not enabled for class ${selection.cls.name}.\n',
              ),
              const _AllocationTracingInstructions(),
            ],
          );
        } else if (selection.traceAllocations &&
            (controller.selectedTracedClassAllocationData == null ||
                controller.selectedTracedClassAllocationData!.bottomUpRoots
                    .isEmpty)) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No allocation samples have been collected for class ${selection.cls.name}.\n',
              ),
            ],
          );
        }
        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                _AllocationProfileTracingTreeHeader(
                  controller: controller,
                  updateTreeStateCallback: setState,
                ),
                Expanded(
                  child: AllocationProfileTracingBottomUpTable(
                    cls: selection.cls,
                    // TODO(bkonyi): support call stack and bottom up views.
                    dataRoots: controller
                        .selectedTracedClassAllocationData!.bottomUpRoots,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AllocationTracingInstructions extends StatelessWidget {
  const _AllocationTracingInstructions({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'To trace allocations for a class, enable the '
          'checkbox for that class in the table.',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'After interacting with your app, come '
              'back to tab and click the refresh button ',
            ),
            Icon(
              Icons.refresh,
              size: defaultIconSize,
            ),
          ],
        ),
        const Text(
          'to view the tree of collected stack '
          'traces of constructor calls.',
        ),
      ],
    );
  }
}

class _AllocationProfileTracingTreeHeader extends StatelessWidget {
  const _AllocationProfileTracingTreeHeader({
    Key? key,
    required this.controller,
    required this.updateTreeStateCallback,
  }) : super(key: key);

  final AllocationProfileTracingViewController controller;
  final Function(VoidCallback) updateTreeStateCallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AreaPaneHeader(
      title: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'Traced allocations for: ',
            ),
            TextSpan(
              style: theme.fixedFontStyle,
              text: controller.selectedTracedClass.value?.cls.name!,
            ),
          ],
        ),
      ),
      tall: true,
      needsTopBorder: false,
      actions: [
        ExpandAllButton(
          onPressed: () => updateTreeStateCallback(
            () {
              final data = controller.selectedTracedClassAllocationData!;
              for (final root in data.bottomUpRoots) {
                root.expandCascading();
              }
            },
          ),
        ),
        const SizedBox(width: denseSpacing),
        CollapseAllButton(
          onPressed: () => updateTreeStateCallback(
            () {
              final data = controller.selectedTracedClassAllocationData!;
              for (final root in data.bottomUpRoots) {
                root.collapseCascading();
              }
            },
          ),
        ),
      ],
    );
  }
}

class _InclusiveCountColumn extends ColumnData<CpuStackFrame> {
  _InclusiveCountColumn()
      : super(
          'Inclusive',
          titleTooltip: _tooltip,
          fixedWidthPx: scaleByFontFactor(_countColumnWidth),
        );

  static const _tooltip =
      'The number of instances allocated by calls made from a stack frame.';

  @override
  bool get numeric => true;

  @override
  int compare(CpuStackFrame a, CpuStackFrame b) {
    final int result = super.compare(a, b);
    if (result == 0) {
      return a.name.compareTo(b.name);
    }
    return result;
  }

  @override
  int getValue(CpuStackFrame dataObject) => dataObject.inclusiveSampleCount;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${dataObject.inclusiveSampleCount} '
        '(${percent2(dataObject.inclusiveSampleRatio)})';
  }
}

class _ExclusiveCountColumn extends ColumnData<CpuStackFrame> {
  _ExclusiveCountColumn()
      : super(
          'Exclusive',
          titleTooltip: _tooltip,
          fixedWidthPx: scaleByFontFactor(_countColumnWidth),
        );

  static const _tooltip =
      'The number of instances allocated directly by a stack frame.';

  @override
  bool get numeric => true;

  @override
  int compare(CpuStackFrame a, CpuStackFrame b) {
    final int result = super.compare(a, b);
    if (result == 0) {
      return a.name.compareTo(b.name);
    }
    return result;
  }

  @override
  int getValue(CpuStackFrame dataObject) => dataObject.exclusiveSampleCount;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${dataObject.exclusiveSampleCount} '
        '(${percent2(dataObject.exclusiveSampleRatio)})';
  }
}

/// A table of the bottom-up allocation profile tree.
class AllocationProfileTracingBottomUpTable extends StatefulWidget {
  const AllocationProfileTracingBottomUpTable({
    Key? key,
    required this.cls,
    required this.dataRoots,
  }) : super(key: key);

  final ClassRef cls;
  final List<CpuStackFrame> dataRoots;

  @override
  State<AllocationProfileTracingBottomUpTable> createState() {
    return _AllocationProfileTracingBottomUpTableState();
  }
}

class _AllocationProfileTracingBottomUpTableState
    extends State<AllocationProfileTracingBottomUpTable> {
  static final treeColumn = MethodNameColumn();
  static final startingSortColumn = _InclusiveCountColumn();
  static final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
    startingSortColumn,
    _ExclusiveCountColumn(),
    treeColumn,
    SourceColumn(),
  ]);

  // TODO(bkonyi): this is a common pattern when creating tables that can be
  // refreshed. Consider pulling this state into a "TableController".
  // See: https://github.com/flutter/devtools/issues/4365
  late ColumnData<CpuStackFrame> sortColumn;
  late SortDirection sortDirection;

  @override
  void initState() {
    super.initState();
    sortColumn = startingSortColumn;
    sortDirection = SortDirection.descending;
  }

  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      dataRoots: widget.dataRoots,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      sortColumn: sortColumn,
      sortDirection: sortDirection,
      onSortChanged: (column, direction, {secondarySortColumn}) {
        setState(() {
          sortColumn = column;
          sortDirection = direction;
        });
      },
    );
  }
}
