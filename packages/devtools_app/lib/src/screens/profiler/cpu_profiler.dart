// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/charts/flame_chart.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/tab.dart';
import 'common.dart';
import 'cpu_profile_model.dart';
import 'cpu_profiler_controller.dart';
import 'panes/bottom_up.dart';
import 'panes/call_tree.dart';
import 'panes/controls/cpu_profiler_controls.dart';
import 'panes/cpu_flame_chart.dart';
import 'panes/method_table/method_table.dart';
import 'panes/method_table/method_table_controller.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  CpuProfiler({
    super.key,
    required this.data,
    required this.controller,
    List<Key>? searchableTabKeys,
  })  : callTreeRoots = data.callTreeRoots,
        bottomUpRoots = data.bottomUpRoots,
        tabs = [
          _buildTab(ProfilerTab.bottomUp),
          _buildTab(ProfilerTab.callTree),
          _buildTab(ProfilerTab.methodTable),
          _buildTab(ProfilerTab.cpuFlameChart),
        ];

  static DevToolsTab _buildTab(ProfilerTab profilerTab) {
    return DevToolsTab.create(
      key: profilerTab.key,
      tabName: profilerTab.title,
      gaPrefix: 'cpuProfilerTab',
    );
  }

  final CpuProfileData data;

  final CpuProfilerController controller;

  final List<CpuStackFrame> callTreeRoots;

  final List<CpuStackFrame> bottomUpRoots;

  final List<DevToolsTab> tabs;

  static const Key dataProcessingKey = Key('CpuProfiler - data is processing');

  static final searchableTabKeys = <Key>[
    ProfilerTab.methodTable.key,
    ProfilerTab.cpuFlameChart.key,
  ];

  @override
  State<CpuProfiler> createState() => _CpuProfilerState();
}

// TODO(kenz): preserve tab controller index when updating CpuProfiler with new
// data. The state is being destroyed with every new cpu profile - investigate.
class _CpuProfilerState extends State<CpuProfiler>
    with TickerProviderStateMixin, AutoDisposeMixin {
  static const _expandCollapseMinIncludeTextWidth = 1070.0;

  bool _tabControllerInitialized = false;

  late TabController _tabController;

  late CpuProfileData data;

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
      const index = 0;
      widget.controller.changeSelectedProfilerTab(
        index,
        ProfilerTab.byKey(widget.tabs[index].key),
      );
    }
    _tabController
      ..index = widget.controller.selectedProfilerTabIndex
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    setState(() {
      final index = _tabController.index;
      widget.controller.changeSelectedProfilerTab(
        index,
        ProfilerTab.byKey(widget.tabs[index].key),
      );
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
          leftPadding: 0,
          tall: true,
          title: TabBar(
            labelColor: textTheme.bodyLarge?.color ?? colorScheme.onSurface,
            isScrollable: true,
            controller: _tabController,
            tabs: widget.tabs,
          ),
          actions: [
            DevToolsFilterButton(
              onPressed: _showFilterDialog,
              isFilterActive: widget.controller.isFilterActive,
            ),
            const SizedBox(width: denseSpacing),
            if (currentTab.key != ProfilerTab.cpuFlameChart.key &&
                currentTab.key != ProfilerTab.methodTable.key) ...[
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

            // TODO(kenz): support search for call tree and bottom up tabs as
            // well. This will require implementing search for tree tables.
            if (CpuProfiler.searchableTabKeys.contains(currentTab.key)) ...[
              if (currentTab.key == ProfilerTab.methodTable.key)
                SearchField<MethodTableController>(
                  searchController: widget.controller.methodTableController,
                  containerPadding: EdgeInsets.zero,
                )
              else
                SearchField<CpuProfilerController>(
                  searchController: widget.controller,
                  containerPadding: EdgeInsets.zero,
                ),
            ],
            if (currentTab.key == ProfilerTab.cpuFlameChart.key) ...[
              Padding(
                padding: const EdgeInsets.only(left: denseSpacing),
                child: FlameChartHelpButton(
                  gaScreen: gac.cpuProfiler,
                  gaSelection:
                      gac.CpuProfilerEvents.cpuProfileFlameChartHelp.name,
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
              ),
            ],
            if (currentTab.key == ProfilerTab.callTree.key ||
                currentTab.key == ProfilerTab.bottomUp.key) ...[
              // TODO(kenz): add a switch to order samples by user tag here
              // instead of using the filter control. This will allow users
              // to see all the tags side by side in the tree tables.
              ExpandAllButton(
                gaScreen: gac.cpuProfiler,
                gaSelection: gac.expandAll,
                minScreenWidthForTextBeforeScaling:
                    _expandCollapseMinIncludeTextWidth,
                onPressed: () {
                  _performOnDataRoots(
                    (root) => root.expandCascading(),
                    currentTab,
                  );
                },
              ),
              const SizedBox(width: denseSpacing),
              CollapseAllButton(
                gaScreen: gac.cpuProfiler,
                gaSelection: gac.collapseAll,
                minScreenWidthForTextBeforeScaling:
                    _expandCollapseMinIncludeTextWidth,
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
              child: OutlineDecoration(
                showTop: false,
                showBottom: false,
                child: TabBarView(
                  physics: defaultTabBarViewPhysics,
                  controller: _tabController,
                  children: _buildProfilerViews(),
                ),
              ),
            );
          },
        ),
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
    return [
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
    final roots = currentTab.key == ProfilerTab.callTree.key
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
  CpuProfileStats({super.key, required this.metadata});

  final CpuProfileMetaData metadata;

  final _statsRowHeight = scaleByFontFactor(25.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final samplePeriodValid = metadata.samplePeriod > 0;
    final samplingPeriodDisplay = samplePeriodValid
        ? const Duration(seconds: 1).inMicroseconds ~/ metadata.samplePeriod
        : '--';
    return RoundedOutlinedBorder.onlyBottom(
      child: Container(
        height: _statsRowHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: defaultSpacing,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat(
              tooltip: 'The duration of time spanned by the CPU samples',
              text: 'Duration: ${durationText(metadata.time!.duration)}',
              theme: theme,
            ),
            _stat(
              tooltip: 'The number of samples included in the profile',
              text: 'Sample count: ${metadata.sampleCount}',
              theme: theme,
            ),
            _stat(
              tooltip:
                  'The frequency at which samples are collected by the profiler'
                  '${samplePeriodValid ? ' (once every ${metadata.samplePeriod} micros)' : ''}',
              text: 'Sampling rate: $samplingPeriodDisplay Hz',
              theme: theme,
            ),
            _stat(
              tooltip: 'The maximum stack trace depth of a collected sample',
              text: 'Sampling depth: ${metadata.stackDepth}',
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat({
    required String text,
    required String tooltip,
    required ThemeData theme,
  }) {
    return Flexible(
      child: DevToolsTooltip(
        message: tooltip,
        child: Text(
          text,
          style: theme.subtleTextStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
