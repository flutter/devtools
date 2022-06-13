// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer';

import 'package:flutter/material.dart';

import '../../analytics/constants.dart' as analytics_constants;
import '../../charts/flame_chart.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/notifications.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/colors.dart';
import '../../ui/filter.dart';
import '../../ui/search.dart';
import '../../ui/tab.dart';
import 'cpu_profile_bottom_up.dart';
import 'cpu_profile_call_tree.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_flame_chart.dart';
import 'cpu_profile_model.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  CpuProfiler({
    required this.data,
    required this.controller,
    this.searchFieldKey,
    this.standaloneProfiler = true,
    this.summaryView,
  })  : callTreeRoots = data.callTreeRoots,
        bottomUpRoots = data.bottomUpRoots,
        tabs = [
          if (summaryView != null)
            _buildTab(key: summaryTab, tabName: 'Summary'),
          if (!data.isEmpty) ...[
            _buildTab(key: bottomUpTab, tabName: 'Bottom Up'),
            _buildTab(key: callTreeTab, tabName: 'Call Tree'),
            _buildTab(key: flameChartTab, tabName: 'CPU Flame Chart'),
          ],
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

  final GlobalKey? searchFieldKey;

  final bool standaloneProfiler;

  final Widget? summaryView;

  final List<DevToolsTab> tabs;

  static const Key dataProcessingKey = Key('CpuProfiler - data is processing');

  // When content of the selected DevToolsTab from the tab controller has this key,
  // we will not show the expand/collapse buttons.
  static const Key flameChartTab = Key('cpu profile flame chart tab');
  static const Key callTreeTab = Key('cpu profile call tree tab');
  static const Key bottomUpTab = Key('cpu profile bottom up tab');
  static const Key summaryTab = Key('cpu profile summary tab');

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
      setState(() {
        data = widget.data;
      });
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
    final currentTab =
        widget.tabs.isNotEmpty ? widget.tabs[_tabController.index] : null;
    final hasData =
        data != CpuProfilerController.baseStateCpuProfileData && !data.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: defaultButtonHeight,
          child: Row(
            children: [
              TabBar(
                labelColor:
                    textTheme.bodyText1?.color ?? colorScheme.defaultForeground,
                isScrollable: true,
                controller: _tabController,
                tabs: widget.tabs,
              ),
              const Spacer(),
              if (hasData) ...[
                if (currentTab!.key != CpuProfiler.summaryTab) ...[
                  FilterButton(
                    onPressed: _showFilterDialog,
                    isFilterActive: widget.controller.isToggleFilterActive,
                  ),
                  const SizedBox(width: denseSpacing),
                  UserTagDropdown(widget.controller),
                  const SizedBox(width: denseSpacing),
                ],
                // TODO(kenz): support search for call tree and bottom up tabs as
                // well. This will require implementing search for tree tables.
                if (currentTab.key == CpuProfiler.flameChartTab)
                  Row(
                    children: [
                      if (widget.searchFieldKey != null)
                        _buildSearchField(hasData),
                      FlameChartHelpButton(
                        gaScreen: widget.standaloneProfiler
                            ? analytics_constants.cpuProfiler
                            : analytics_constants.performance,
                        gaSelection:
                            analytics_constants.cpuProfileFlameChartHelp,
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
                                nativeCodeColor.background
                                    .colorFor(colorScheme),
                              ),
                              LegendEntry(
                                'Dart core libraries (code from the Dart SDK)',
                                dartCoreColor.background.colorFor(colorScheme),
                              ),
                              LegendEntry(
                                'Flutter Framework (code from the Flutter SDK)',
                                flutterCoreColor.background
                                    .colorFor(colorScheme),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                if (currentTab.key != CpuProfiler.flameChartTab &&
                    currentTab.key != CpuProfiler.summaryTab)
                  Row(
                    children: [
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
                      // The standaloneProfiler does not need padding because it is
                      // not wrapped in a bordered container.
                      if (!widget.standaloneProfiler)
                        const SizedBox(width: denseSpacing),
                    ],
                  ),
              ],
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            controller: _tabController,
            children: _buildProfilerViews(),
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => CpuProfileFilterDialog(
        controller: widget.controller,
      ),
    );
  }

  Widget _buildSearchField(bool hasData) {
    return Container(
      width: wideSearchTextWidth,
      height: defaultTextFieldHeight,
      child: buildSearchField(
        controller: widget.controller,
        searchFieldKey: widget.searchFieldKey!,
        searchFieldEnabled: hasData,
        shouldRequestFocus: false,
        supportsNavigation: true,
      ),
    );
  }

  List<Widget> _buildProfilerViews() {
    final bottomUp = KeepAliveWrapper(
      child: CpuBottomUpTable(widget.bottomUpRoots),
    );
    final callTree = KeepAliveWrapper(
      child: CpuCallTreeTable(widget.callTreeRoots),
    );
    final cpuFlameChart = KeepAliveWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CpuProfileFlameChart(
            data: data,
            controller: widget.controller,
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
      if (!data.isEmpty) ...[
        bottomUp,
        callTree,
        cpuFlameChart,
      ],
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

class CpuProfileFilterDialog extends StatelessWidget {
  CpuProfileFilterDialog({
    required this.controller,
    Key? key,
  })  : oldToggleFilterValues = List.generate(
          controller.toggleFilters.length,
          (index) => controller.toggleFilters[index].enabled.value,
        ),
        super(key: key);

  double get _filterDialogWidth => scaleByFontFactor(400.0);

  final CpuProfilerController controller;

  final List<bool> oldToggleFilterValues;

  @override
  Widget build(BuildContext context) {
    return FilterDialog<CpuProfilerController, CpuStackFrame>(
      includeQueryFilter: false,
      dialogWidth: _filterDialogWidth,
      controller: controller,
      onCancel: restoreOldValues,
      toggleFilters: controller.toggleFilters,
    );
  }

  void restoreOldValues() {
    for (var i = 0; i < controller.toggleFilters.length; i++) {
      final filter = controller.toggleFilters[i];
      filter.enabled.value = oldToggleFilterValues[i];
    }
  }
}

class CpuProfilerDisabled extends StatelessWidget {
  const CpuProfilerDisabled(this.controller);

  final CpuProfilerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('CPU profiler is disabled.'),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: controller.enableCpuProfiler,
              child: const Text('Enable profiler'),
            ),
          ),
        ],
      ),
    );
  }
}

/// DropdownButton that controls the value of
/// [ProfilerScreenController.userTagFilter].
class UserTagDropdown extends StatelessWidget {
  const UserTagDropdown(this.controller);

  final CpuProfilerController controller;

  @override
  Widget build(BuildContext context) {
    const filterByTag = 'Filter by tag:';
    return ValueListenableBuilder<String>(
      valueListenable: controller.userTagFilter,
      builder: (context, userTag, _) {
        final userTags = controller.userTags;
        final tooltip = userTags.isNotEmpty
            ? 'Filter the CPU profile by the given UserTag'
            : 'No UserTags found for this CPU profile';
        return DevToolsTooltip(
          message: tooltip,
          child: RoundedDropDownButton<String>(
            isDense: true,
            style: Theme.of(context).textTheme.bodyText2,
            value: userTag,
            items: [
              _buildMenuItem(
                display: '$filterByTag ${CpuProfilerController.userTagNone}',
                value: CpuProfilerController.userTagNone,
              ),
              // We don't want to show the 'Default' tag if it is the only
              // tag available. The 'none' tag above is equivalent in this
              // case.
              if (!(userTags.length == 1 &&
                  userTags.first == UserTag.defaultTag.label))
                for (final tag in userTags)
                  _buildMenuItem(
                    display: '$filterByTag $tag',
                    value: tag,
                  ),
            ],
            onChanged: userTags.isEmpty ||
                    (userTags.length == 1 &&
                        userTags.first == UserTag.defaultTag.label)
                ? null
                : (String? tag) => _onUserTagChanged(tag!, context),
          ),
        );
      },
    );
  }

  DropdownMenuItem<String> _buildMenuItem({
    required String display,
    required String value,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: Text(display),
    );
  }

  void _onUserTagChanged(String newTag, BuildContext context) async {
    try {
      await controller.loadDataWithTag(newTag);
    } catch (e) {
      Notifications.of(context)!.push(e.toString());
    }
  }
}
