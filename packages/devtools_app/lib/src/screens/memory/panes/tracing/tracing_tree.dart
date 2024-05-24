// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_data.dart';
import '../../../../shared/ui/tab.dart';
import '../../../profiler/cpu_profile_model.dart';
import '../../../profiler/panes/cpu_profile_columns.dart';
import 'tracing_data.dart';
import 'tracing_pane_controller.dart';

const double _countColumnWidth = 100;

/// Displays an allocation profile as a tree of stack frames, displaying
/// inclusive and exclusive allocation counts.
class AllocationTracingTree extends StatefulWidget {
  const AllocationTracingTree({super.key, required this.controller});

  final TracingPaneController controller;

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
    return ValueListenableBuilder<TracingIsolateState>(
      valueListenable: widget.controller.selection,
      builder: (context, state, _) {
        return ValueListenableBuilder<TracedClass?>(
          valueListenable: state.selectedTracedClass,
          builder: (context, selection, _) {
            if (selection == null) {
              return const _TracingInstructions();
            } else if (!selection.traceAllocations) {
              return _TracingInstructions(
                prefix: 'Allocation tracing is not enabled for class '
                    '${selection.cls.name}.',
              );
            } else if (selection.traceAllocations &&
                (state.selectedTracedClassAllocationData == null ||
                    state.selectedTracedClassAllocationData!.bottomUpRoots
                        .isEmpty)) {
              return Padding(
                padding: const EdgeInsets.all(largeSpacing),
                child: Text(
                  'No allocation samples have been collected for class ${selection.cls.name}.\n',
                ),
              );
            }
            return Column(
              children: [
                _TracingTreeHeader(
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
                      TracingTable(
                        dataRoots: state
                            .selectedTracedClassAllocationData!.bottomUpRoots,
                      ),
                      // Call tree view
                      TracingTable(
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

class _TracingInstructions extends StatelessWidget {
  const _TracingInstructions({
    this.prefix,
  });

  final String? prefix;

  @override
  Widget build(BuildContext context) {
    var data = _tracingInstructions;
    if (prefix != null) {
      data = '$prefix\n\n$data';
    }
    return Markdown(
      data: data,
      styleSheet: MarkdownStyleSheet(
        p: Theme.of(context).regularTextStyle,
      ),
    );
  }
}

/// `\v` adds vertical space
const _tracingInstructions = '''
To trace allocations for a class:

\v

1. Enable the 'Trace' checkbox for that class in the table.

2. Interact with your app to trigger an allocation of the class.

3. Click 'Refresh' above to view the tree of collected stack traces of
constructor calls for the selected class.
''';

class _TracingTreeHeader extends StatelessWidget {
  const _TracingTreeHeader({
    required this.controller,
    required this.tabController,
    required this.tabs,
    required this.updateTreeStateCallback,
  });

  final TracingPaneController controller;
  final void Function(VoidCallback) updateTreeStateCallback;
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
                  .selection.value.selectedTracedClass.value?.cls.name!,
            ),
          ],
        ),
      ),
      tall: true,
      includeTopBorder: false,
      actions: [
        const Spacer(),
        TabBar(
          labelColor: textTheme.bodyLarge?.color ?? colorScheme.primary,
          tabs: tabs,
          isScrollable: true,
          controller: tabController,
        ),
        const SizedBox(width: denseSpacing),
        ExpandAllButton(
          gaScreen: gac.memory,
          gaSelection: gac.MemoryEvent.tracingTreeExpandAll,
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
          gaScreen: gac.memory,
          gaSelection: gac.MemoryEvent.tracingTreeCollapseAll,
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
    final data = controller.selection.value.selectedTracedClassAllocationData!;
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
        '(${percent(dataObject.inclusiveSampleRatio)})';
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
        '(${percent(dataObject.exclusiveSampleRatio)})';
  }
}

/// A table of an allocation profile tree.
class TracingTable extends StatelessWidget {
  const TracingTable({
    super.key,
    required this.dataRoots,
  });

  static final treeColumn = MethodAndSourceColumn();
  static final startingSortColumn = _InclusiveCountColumn();
  static final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
    startingSortColumn,
    _ExclusiveCountColumn(),
    treeColumn,
  ]);

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
