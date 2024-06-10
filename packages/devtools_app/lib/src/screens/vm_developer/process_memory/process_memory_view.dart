// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/charts/treemap.dart';
import '../../../shared/common_widgets.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/table/table.dart';
import '../../../shared/table/table_data.dart';
import '../../../shared/ui/tab.dart';
import '../vm_developer_tools_screen.dart';
import 'process_memory_tree_columns.dart';
import 'process_memory_view_controller.dart';

/// Displays a breakdown of the target application's overall memory footprint.
///
/// This allows for developers to determine:
///
///  - The total resident set size (RSS)
///  - How much memory can be attributed to each isolate group's heap,
///    including system isolate groups like the vm-service and kernel-service
///  - How much memory can be attributed to developer tooling functionality
///    (e.g., CPU profiler buffer size, size of all recorded timeline events)
///
/// This view provides both a tree table and a tree map to explore the
/// process's memory footprint.
class VMProcessMemoryView extends VMDeveloperView {
  const VMProcessMemoryView()
      : super(
          title: 'Process Memory',
          icon: Icons.memory,
        );

  static const id = 'vm-process-memory';

  @override
  Widget build(BuildContext context) => VMProcessMemoryViewBody();
}

enum ProcessMemoryTab {
  tree('Tree', _treeTab),
  treeMap('Tree Map', _treeMapTab);

  const ProcessMemoryTab(this.title, this.key);

  final String title;
  final Key key;

  static const _treeTab = Key('process memory usage tree tab');
  static const _treeMapTab = Key('process memory usage tree map tab');

  static ProcessMemoryTab byKey(Key? k) {
    return ProcessMemoryTab.values.firstWhere((tab) => tab.key == k);
  }
}

class VMProcessMemoryViewBody extends StatefulWidget {
  VMProcessMemoryViewBody({super.key})
      : tabs = [
          _buildTab(ProcessMemoryTab.tree),
          _buildTab(ProcessMemoryTab.treeMap),
        ];

  static DevToolsTab _buildTab(ProcessMemoryTab processMemoryTab) {
    return DevToolsTab.create(
      key: processMemoryTab.key,
      tabName: processMemoryTab.title,
      gaPrefix: 'processMemoryTab',
    );
  }

  final List<DevToolsTab> tabs;

  @override
  State<VMProcessMemoryViewBody> createState() =>
      _VMProcessMemoryViewBodyState();
}

class _VMProcessMemoryViewBodyState extends State<VMProcessMemoryViewBody>
    with TickerProviderStateMixin, AutoDisposeMixin {
  static const _expandCollapseMinIncludeTextWidth = 610.0;

  final controller = VMProcessMemoryViewController();

  bool _tabControllerInitialized = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  @override
  void didUpdateWidget(VMProcessMemoryViewBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _initTabController();
    }
  }

  void _initTabController() {
    if (_tabControllerInitialized) {
      _tabController
        ..removeListener(_onTabChanged)
        ..dispose();
    }

    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    )..addListener(_onTabChanged);
    _tabControllerInitialized = true;
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final currentTab = widget.tabs[_tabController.index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefreshButton(
          gaScreen: gac.vmTools,
          gaSelection: gac.refreshProcessMemoryStatistics,
          onPressed: controller.refresh,
        ),
        const SizedBox(height: denseRowSpacing),
        AreaPaneHeader(
          leftPadding: 0,
          tall: true,
          title: TabBar(
            labelColor: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
            isScrollable: true,
            controller: _tabController,
            tabs: widget.tabs,
          ),
          actions: [
            if (currentTab.key == ProcessMemoryTab.tree.key) ...[
              ExpandAllButton(
                gaScreen: gac.cpuProfiler,
                gaSelection: gac.expandAll,
                minScreenWidthForTextBeforeScaling:
                    _expandCollapseMinIncludeTextWidth,
                onPressed: () => setState(controller.expandTree),
              ),
              const SizedBox(width: denseSpacing),
              CollapseAllButton(
                gaScreen: gac.cpuProfiler,
                gaSelection: gac.collapseAll,
                minScreenWidthForTextBeforeScaling:
                    _expandCollapseMinIncludeTextWidth,
                onPressed: () => setState(controller.collapseTree),
              ),
            ],
          ],
        ),
        Expanded(
          child: OutlineDecoration(
            showTop: false,
            child: TabBarView(
              physics: defaultTabBarViewPhysics,
              controller: _tabController,
              children: [
                _ProcessMemoryTree(controller: controller),
                _ProcessMemoryTreeMap(controller: controller),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcessMemoryTree extends StatelessWidget {
  _ProcessMemoryTree({
    required this.controller,
  });

  final VMProcessMemoryViewController controller;

  static final categoryColumn = CategoryColumn();
  static final descriptionColumn = DescriptionColumn();

  late final memoryColumn = MemoryColumn(controller: controller);
  late final columns = List<ColumnData<TreemapNode>>.unmodifiable([
    memoryColumn,
    categoryColumn,
    descriptionColumn,
  ]);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TreemapNode?>(
      valueListenable: controller.treeRoot,
      builder: (context, root, _) {
        return TreeTable<TreemapNode>(
          keyFactory: (e) =>
              PageStorageKey<String>('${e.name}+${e.depth}+${e.byteSize}'),
          displayTreeGuidelines: true,
          dataRoots: [
            if (root != null) root,
          ],
          dataKey: 'process-memory-tree',
          columns: columns,
          treeColumn: categoryColumn,
          defaultSortColumn: memoryColumn,
          defaultSortDirection: SortDirection.descending,
        );
      },
    );
  }
}

class _ProcessMemoryTreeMap extends StatelessWidget {
  const _ProcessMemoryTreeMap({
    required this.controller,
  });

  final VMProcessMemoryViewController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ValueListenableBuilder<TreemapNode?>(
          valueListenable: controller.treeMapRoot,
          builder: (context, root, __) {
            return Treemap.fromRoot(
              rootNode: root!,
              levelsVisible: 2,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              isOutermostLevel: true,
              onRootChangedCallback: controller.setTreeMapRoot,
            );
          },
        );
      },
    );
  }
}
