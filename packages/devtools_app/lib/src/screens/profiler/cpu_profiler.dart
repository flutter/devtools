// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/charts/flame_chart.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/theme.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/tab.dart';
import '../../shared/utils.dart';
import 'cpu_profile_model.dart';
import 'cpu_profiler_controller.dart';
import 'panes/bottom_up.dart';
import 'panes/call_tree.dart';
import 'panes/controls/profiler_controls.dart';
import 'panes/cpu_flame_chart.dart';
import 'panes/method_table/method_table.dart';
import 'panes/method_table/method_table_model.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  CpuProfiler({
    required this.data,
    required this.controller,
    this.standaloneProfiler = true,
    this.summaryView,
    List<Key>? searchableTabKeys,
  })  : callTreeRoots = data.callTreeRoots,
        bottomUpRoots = data.bottomUpRoots,
        tabs = [
          if (summaryView != null)
            _buildTab(key: summaryTab, tabName: 'Summary'),
          _buildTab(key: bottomUpTab, tabName: 'Bottom Up'),
          _buildTab(key: callTreeTab, tabName: 'Call Tree'),
          _buildTab(key: methodTableTab, tabName: 'Method Table'),
          _buildTab(key: flameChartTab, tabName: 'CPU Flame Chart'),
        ];

  static DevToolsTab _buildTab({Key? key, required String tabName}) {
    return DevToolsTab.create(
      key: key,
      tabName: tabName,
      gaPrefix: 'cpuProfilerTab',
    );
  }

  final CpuProfileData data;

  final CpuProfilerController controller;

  final List<CpuStackFrame> callTreeRoots;

  final List<CpuStackFrame> bottomUpRoots;

  final bool standaloneProfiler;

  final Widget? summaryView;

  final List<DevToolsTab> tabs;

  static const Key dataProcessingKey = Key('CpuProfiler - data is processing');

  // When content of the selected DevToolsTab from the tab controller has any
  // of these three keys, we will not show the expand/collapse buttons.
  static const Key flameChartTab = Key('cpu profile flame chart tab');
  static const Key methodTableTab = Key('cpu profile method table tab');
  static const Key summaryTab = Key('cpu profile summary tab');

  static const Key bottomUpTab = Key('cpu profile bottom up tab');
  static const Key callTreeTab = Key('cpu profile call tree tab');

  static const searchableTabKeys = <Key>[methodTableTab, flameChartTab];

  @override
  _CpuProfilerState createState() => _CpuProfilerState();
}

// TODO(kenz): preserve tab controller index when updating CpuProfiler with new
// data. The state is being destroyed with every new cpu profile - investigate.
class _CpuProfilerState extends State<CpuProfiler>
    with
        TickerProviderStateMixin,
        AutoDisposeMixin,
        SearchFieldMixin<CpuProfiler> {
  bool _tabControllerInitialized = false;

  late TabController _tabController;

  late CpuProfileData data;

  @override
  SearchControllerMixin get searchController => widget.controller;

  @override
  void initState() {
    super.initState();
    data = widget.data;
    _initTabController();
  }

  @override
  void didUpdateWidget(CpuProfiler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _initTabController();
    }
    if (widget.data != oldWidget.data) {
      data = widget.data;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _initTabController() {
    if (_tabControllerInitialized) {
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
    }
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    );
    _tabControllerInitialized = true;

    if (widget.controller.selectedProfilerTabIndex >= _tabController.length) {
      widget.controller.changeSelectedProfilerTab(0);
    }
    _tabController
      ..index = widget.controller.selectedProfilerTabIndex
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    setState(() {
      widget.controller.changeSelectedProfilerTab(_tabController.index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final currentTab = widget.tabs[_tabController.index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AreaPaneHeader(
          needsTopBorder: false,
          leftPadding: 0,
          tall: true,
          title: TabBar(
            labelColor:
                textTheme.bodyLarge?.color ?? colorScheme.defaultForeground,
            isScrollable: true,
            controller: _tabController,
            tabs: widget.tabs,
          ),
          actions: [
            if (currentTab.key != CpuProfiler.summaryTab) ...[
              FilterButton(
                onPressed: _showFilterDialog,
                isFilterActive: widget.controller.isFilterActive,
              ),
              const SizedBox(width: denseSpacing),
              if (currentTab.key != CpuProfiler.flameChartTab &&
                  currentTab.key != CpuProfiler.methodTableTab) ...[
                const DisplayTreeGuidelinesToggle(),
                const SizedBox(width: denseSpacing),
              ],
              UserTagDropdown(widget.controller),
              const SizedBox(width: denseSpacing),
              ValueListenableBuilder<bool>(
                valueListenable: preferences.vmDeveloperModeEnabled,
                builder: (context, vmDeveloperModeEnabled, _) {
                  if (!vmDeveloperModeEnabled) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: denseSpacing),
                    child: ModeDropdown(widget.controller),
                  );
                },
              ),
            ],
            // TODO(kenz): support search for call tree and bottom up tabs as
            // well. This will require implementing search for tree tables.
            if (CpuProfiler.searchableTabKeys.contains(currentTab.key)) ...[
              if (currentTab.key == CpuProfiler.methodTableTab)
                _buildSearchField<MethodTableGraphNode>(
                  widget.controller.methodTableController,
                )
              else
                _buildSearchField<CpuStackFrame>(widget.controller),
            ],
            if (currentTab.key == CpuProfiler.flameChartTab) ...[
              FlameChartHelpButton(
                gaScreen: widget.standaloneProfiler
                    ? gac.cpuProfiler
                    : gac.performance,
                gaSelection: gac.cpuProfileFlameChartHelp,
                additionalInfo: [
                  ...dialogSubHeader(Theme.of(context), 'Legend'),
                  Legend(
                    entries: [
                      LegendEntry(
                        'App code (code from your app and imported packages)',
                        appCodeColor.background.colorFor(colorScheme),
                      ),
                      LegendEntry(
                        'Native code (code from the native runtime - Android, iOS, etc.)',
                        nativeCodeColor.background.colorFor(colorScheme),
                      ),
                      LegendEntry(
                        'Dart core libraries (code from the Dart SDK)',
                        dartCoreColor.background.colorFor(colorScheme),
                      ),
                      LegendEntry(
                        'Flutter Framework (code from the Flutter SDK)',
                        flutterCoreColor.background.colorFor(colorScheme),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (currentTab.key != CpuProfiler.flameChartTab &&
                currentTab.key != CpuProfiler.summaryTab &&
                currentTab.key != CpuProfiler.methodTableTab) ...[
              // TODO(kenz): add a switch to order samples by user tag here
              // instead of using the filter control. This will allow users
              // to see all the tags side by side in the tree tables.
              ExpandAllButton(
                onPressed: () {
                  _performOnDataRoots(
                    (root) => root.expandCascading(),
                    currentTab,
                  );
                },
              ),
              const SizedBox(width: denseSpacing),
              CollapseAllButton(
                onPressed: () {
                  _performOnDataRoots(
                    (root) => root.collapseCascading(),
                    currentTab,
                  );
                },
              ),
            ],
          ],
        ),
        ValueListenableBuilder<CpuProfilerViewType>(
          valueListenable: widget.controller.viewType,
          builder: (context, viewType, _) {
            return Expanded(
              child: TabBarView(
                physics: defaultTabBarViewPhysics,
                controller: _tabController,
                children: _buildProfilerViews(),
              ),
            );
          },
        ),
        if (currentTab.key != CpuProfiler.summaryTab)
          CpuProfileStats(metadata: data.profileMetaData),
      ],
    );
  }

  void _showFilterDialog() {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => CpuProfileFilterDialog(
          controller: widget.controller,
        ),
      ),
    );
  }

  Widget _buildSearchField<T extends DataSearchStateMixin>(
    SearchControllerMixin<T> searchController,
  ) {
    return Container(
      width: wideSearchTextWidth,
      height: defaultTextFieldHeight,
      child: SearchField<T>(
        controller: searchController,
        searchFieldEnabled: true,
        shouldRequestFocus: false,
        supportsNavigation: true,
      ),
    );
  }

  List<Widget> _buildProfilerViews() {
    final bottomUp = KeepAliveWrapper(
      child: ValueListenableBuilder<bool>(
        valueListenable: preferences.cpuProfiler.displayTreeGuidelines,
        builder: (context, displayTreeGuidelines, _) {
          return CpuBottomUpTable(
            bottomUpRoots: widget.bottomUpRoots,
            displayTreeGuidelines: displayTreeGuidelines,
          );
        },
      ),
    );
    final callTree = KeepAliveWrapper(
      child: ValueListenableBuilder<bool>(
        valueListenable: preferences.cpuProfiler.displayTreeGuidelines,
        builder: (context, displayTreeGuidelines, _) {
          return CpuCallTreeTable(
            dataRoots: widget.callTreeRoots,
            displayTreeGuidelines: displayTreeGuidelines,
          );
        },
      ),
    );
    final methodTable = KeepAliveWrapper(
      child: CpuMethodTable(
        methodTableController: widget.controller.methodTableController,
      ),
    );
    final cpuFlameChart = KeepAliveWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CpuProfileFlameChart(
            data: data,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            selectionNotifier: widget.controller.selectedCpuStackFrameNotifier,
            searchMatchesNotifier: widget.controller.searchMatches,
            activeSearchMatchNotifier: widget.controller.activeSearchMatch,
            onDataSelected: (sf) => widget.controller.selectCpuStackFrame(sf),
          );
        },
      ),
    );
    final summaryView = widget.summaryView;
    // TODO(kenz): make this order configurable.
    return [
      if (summaryView != null) summaryView,
      bottomUp,
      callTree,
      methodTable,
      cpuFlameChart,
    ];
  }

  void _performOnDataRoots(
    void Function(CpuStackFrame root) callback,
    Tab currentTab,
  ) {
    final roots = currentTab.key == CpuProfiler.callTreeTab
        ? widget.callTreeRoots
        : widget.bottomUpRoots;
    setState(() {
      roots.forEach(callback);
    });
  }
}

// TODO(kenz): one improvement we could make on this is to show the denominator
// for filtered profiles (e.g. 'Sample count: 10/14), or to at least show the
// original value in the tooltip for each of these stats.
class CpuProfileStats extends StatelessWidget {
  CpuProfileStats({required this.metadata});

  final CpuProfileMetaData metadata;

  final _statsRowHeight = scaleByFontFactor(25.0);

  @override
  Widget build(BuildContext context) {
    final samplePeriodValid = metadata.samplePeriod > 0;
    final samplingPeriodDisplay = samplePeriodValid
        ? const Duration(seconds: 1).inMicroseconds ~/ metadata.samplePeriod
        : '--';
    return OutlineDecoration(
      child: Container(
        height: _statsRowHeight,
        padding: const EdgeInsets.all(densePadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat(
              tooltip: 'The duration of time spanned by the CPU samples',
              text: 'Duration: ${msText(metadata.time!.duration)}',
            ),
            _stat(
              tooltip: 'The number of samples included in the profile',
              text: 'Sample count: ${metadata.sampleCount}',
            ),
            _stat(
              tooltip:
                  'The frequency at which samples are collected by the profiler'
                  '${samplePeriodValid ? ' (once every ${metadata.samplePeriod} micros)' : ''}',
              text: 'Sampling rate: $samplingPeriodDisplay Hz',
            ),
            _stat(
              tooltip: 'The maximum stack trace depth of a collected sample',
              text: 'Sampling depth: ${metadata.stackDepth}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat({
    required String text,
    required String tooltip,
  }) {
    return Flexible(
      child: DevToolsTooltip(
        message: tooltip,
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
