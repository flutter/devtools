// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_data.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../../../ui/tab.dart';
import '../../../profiler/cpu_profile_columns.dart';
import '../../../profiler/cpu_profile_model.dart';
import 'allocation_profile_tracing_view_controller.dart';

const double _countColumnWidth = 130;

/// Displays an allocation profile as a tree of stack frames, displaying
/// inclusive and exclusive allocation counts.
class AllocationTracingTree extends StatefulWidget {
  const AllocationTracingTree({required this.controller});

  final AllocationProfileTracingViewController controller;

  static final _bottomUpTab = _buildTab(tabName: 'Bottom Up');
  static final _callTreeTab = _buildTab(tabName: 'Call Tree');
  static final tabs = [
    _bottomUpTab,
    _callTreeTab,
  ];

  static DevToolsTab _buildTab({Key? key, required String tabName}) {
    return DevToolsTab.create(
      key: key,
      tabName: tabName,
      gaPrefix: 'memoryAllocationTracingTab',
    );
  }

  @override
  State<AllocationTracingTree> createState() => _AllocationTracingTreeState();
}

class _AllocationTracingTreeState extends State<AllocationTracingTree>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AllocationTracingTree.tabs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AllocationProfileTracingIsolateState>(
      valueListenable: widget.controller.stateForIsolate,
      builder: (context, state, _) {
        return ValueListenableBuilder<TracedClass?>(
          valueListenable: state.selectedTracedClass,
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
                (state.selectedTracedClassAllocationData == null ||
                    state.selectedTracedClassAllocationData!.bottomUpRoots
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
            return Column(
              children: [
                _AllocationProfileTracingTreeHeader(
                  controller: widget.controller,
                  tabController: _tabController,
                  tabs: AllocationTracingTree.tabs,
                  updateTreeStateCallback: setState,
                ),
                Expanded(
                  child: TabBarView(
                    physics: defaultTabBarViewPhysics,
                    controller: _tabController,
                    children: [
                      // Bottom-up tree view
                      AllocationProfileTracingTable(
                        cls: selection.cls,
                        dataRoots: state
                            .selectedTracedClassAllocationData!.bottomUpRoots,
                      ),
                      // Call tree view
                      AllocationProfileTracingTable(
                        cls: selection.cls,
                        dataRoots: state
                            .selectedTracedClassAllocationData!.callTreeRoots,
                      ),
                    ],
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
    required this.tabController,
    required this.tabs,
    required this.updateTreeStateCallback,
  }) : super(key: key);

  final AllocationProfileTracingViewController controller;
  final Function(VoidCallback) updateTreeStateCallback;
  final TabController tabController;
  final List<DevToolsTab> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    return AreaPaneHeader(
      title: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'Traced allocations for: ',
            ),
            TextSpan(
              style: theme.fixedFontStyle,
              text: controller
                  .stateForIsolate.value.selectedTracedClass.value?.cls.name!,
            ),
          ],
        ),
      ),
      tall: true,
      needsTopBorder: false,
      actions: [
        const Spacer(),
        TabBar(
          labelColor:
              textTheme.bodyLarge?.color ?? colorScheme.defaultForeground,
          tabs: tabs,
          isScrollable: true,
          controller: tabController,
        ),
        const SizedBox(width: denseSpacing),
        ExpandAllButton(
          onPressed: () => updateTreeStateCallback(
            () {
              for (final root in _currentDataRoots) {
                root.expandCascading();
              }
            },
          ),
        ),
        const SizedBox(width: denseSpacing),
        CollapseAllButton(
          onPressed: () => updateTreeStateCallback(
            () {
              for (final root in _currentDataRoots) {
                root.collapseCascading();
              }
            },
          ),
        ),
      ],
    );
  }

  List<CpuStackFrame> get _currentDataRoots {
    final isBottomUp =
        tabs[tabController.index] == AllocationTracingTree._bottomUpTab;
    final data =
        controller.stateForIsolate.value.selectedTracedClassAllocationData!;
    return isBottomUp ? data.bottomUpRoots : data.callTreeRoots;
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

/// A table of an allocation profile tree.
class AllocationProfileTracingTable extends StatelessWidget {
  const AllocationProfileTracingTable({
    Key? key,
    required this.cls,
    required this.dataRoots,
  }) : super(key: key);

  static final treeColumn = MethodNameColumn();
  static final startingSortColumn = _InclusiveCountColumn();
  static final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
    startingSortColumn,
    _ExclusiveCountColumn(),
    treeColumn,
    SourceColumn(),
  ]);

  final ClassRef cls;

  final List<CpuStackFrame> dataRoots;

  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
      dataRoots: dataRoots,
      dataKey: 'allocation-profile-tree',
      columns: columns,
      treeColumn: treeColumn,
      defaultSortColumn: startingSortColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}
