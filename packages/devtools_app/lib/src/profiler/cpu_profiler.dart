// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:developer';

import 'package:flutter/material.dart';

import '../analytics/constants.dart' as analytics_constants;
import '../auto_dispose_mixin.dart';
import '../charts/flame_chart.dart';
import '../common_widgets.dart';
import '../dialogs.dart';
import '../notifications.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../ui/filter.dart';
import '../ui/search.dart';
import '../ui/tab.dart';
import '../utils.dart';
import 'cpu_profile_bottom_up.dart';
import 'cpu_profile_call_tree.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_flame_chart.dart';
import 'cpu_profile_model.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  CpuProfiler({
    @required this.data,
    @required this.controller,
    this.searchFieldKey,
    this.standaloneProfiler = true,
    this.summaryView,
  })  : callTreeRoots = data?.callTreeRoots ?? [],
        bottomUpRoots = data?.bottomUpRoots ?? [],
        tabs = [
          if (summaryView != null)
            DevToolsTab(key: summaryTab, text: 'Summary'),
          if (data != null && !data.isEmpty) ...[
            DevToolsTab(key: bottomUpTab, text: 'Bottom Up'),
            DevToolsTab(key: callTreeTab, text: 'Call Tree'),
            DevToolsTab(key: flameChartTab, text: 'CPU Flame Chart'),
          ],
        ];

  final CpuProfileData data;

  final CpuProfilerController controller;

  final List<CpuStackFrame> callTreeRoots;

  final List<CpuStackFrame> bottomUpRoots;

  final Key searchFieldKey;

  final bool standaloneProfiler;

  final Widget summaryView;

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
  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  @override
  void didUpdateWidget(CpuProfiler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _initTabController();
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _initTabController() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    );

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
    final textTheme = Theme.of(context).textTheme;
    final currentTab =
        widget.tabs.isNotEmpty ? widget.tabs[_tabController.index] : null;
    final hasData =
        widget.data != CpuProfilerController.baseStateCpuProfileData &&
            widget.data != null &&
            !widget.data.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: defaultButtonHeight,
          child: Row(
            children: [
              TabBar(
                labelColor: textTheme.bodyText1.color,
                isScrollable: true,
                controller: _tabController,
                tabs: widget.tabs,
              ),
              const Spacer(),
              if (hasData) ...[
                if (currentTab.key != CpuProfiler.summaryTab) ...[
                  FilterButton(
                    onPressed: _showFilterDialog,
                    isFilterActive: widget.controller.toggleFilters.firstWhere(
                          (filter) => filter.enabled.value,
                          orElse: () => null,
                        ) !=
                        null,
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
                        screenId: widget.standaloneProfiler
                            ? analytics_constants.cpuProfiler
                            : analytics_constants.performance,
                        analyticsAction:
                            analytics_constants.cpuProfileFlameChartHelp,
                        additionalInfo: [
                          ...dialogSubHeader(Theme.of(context), 'Legend'),
                          Legend(
                            entries: [
                              LegendEntry(
                                'App code (code from your app and imported packages)',
                                cpuFlameChartNodeColor.background,
                              ),
                              LegendEntry(
                                'Native code (code from the native runtime - Android, iOS, etc.)',
                                nativeCodeColor.background,
                              ),
                              LegendEntry(
                                'Dart core libraries (code from the Dart SDK)',
                                dartCoreColor.background,
                              ),
                              LegendEntry(
                                'Flutter Framework (code from the Flutter SDK)',
                                flutterCoreColor.background,
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
          child: _buildCpuProfileDataView(),
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
        searchFieldKey: widget.searchFieldKey,
        searchFieldEnabled: hasData,
        shouldRequestFocus: false,
        supportsNavigation: true,
      ),
    );
  }

  Widget _buildCpuProfileDataView() {
    if (widget.data != null) {
      return TabBarView(
        physics: defaultTabBarViewPhysics,
        controller: _tabController,
        children: _buildProfilerViews(),
      );
    } else {
      // If [data] is null, CPU profile data is being processed, so return a
      // placeholder.
      return const SizedBox(key: CpuProfiler.dataProcessingKey);
    }
  }

  List<Widget> _buildProfilerViews() {
    final bottomUp = CpuBottomUpTable(widget.bottomUpRoots);
    final callTree = CpuCallTreeTable(widget.callTreeRoots);
    final cpuFlameChart = LayoutBuilder(
      builder: (context, constraints) {
        return CpuProfileFlameChart(
          data: widget.data,
          controller: widget.controller,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          selectionNotifier: widget.controller.selectedCpuStackFrameNotifier,
          searchMatchesNotifier: widget.controller.searchMatches,
          activeSearchMatchNotifier: widget.controller.activeSearchMatch,
          onDataSelected: (sf) => widget.controller.selectCpuStackFrame(sf),
        );
      },
    );
    // TODO(kenz): make this order configurable.
    return [
      if (widget.summaryView != null) widget.summaryView,
      if (!widget.data.isEmpty) ...[
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
    @required this.controller,
    Key key,
  })  : oldToggleFilterValues = List.generate(controller.toggleFilters.length,
            (index) => controller.toggleFilters[index].enabled.value),
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
              child: const Text('Enable profiler'),
              onPressed: controller.enableCpuProfiler,
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
    // This needs to rebuild whenever there is new CPU profile data because the
    // user tags will change with the data.
    // TODO(kenz): remove the nested ValueListenableBuilders
    // https://github.com/flutter/devtools/issues/2989.
    return ValueListenableBuilder<CpuProfileData>(
      valueListenable: controller.dataNotifier,
      builder: (context, cpuProfileData, _) {
        return ValueListenableBuilder<String>(
          valueListenable: controller.userTagFilter,
          builder: (context, userTag, _) {
            final userTags = controller.userTags ?? [];
            final tooltip = userTags.isNotEmpty
                ? 'Filter the CPU profile by the given UserTag'
                : 'No UserTags found for this CPU profile';
            return DevToolsTooltip(
              tooltip: tooltip,
              child: RoundedDropDownButton<String>(
                isDense: true,
                style: Theme.of(context).textTheme.bodyText2,
                value: userTag,
                items: [
                  _buildMenuItem(
                    display:
                        '$filterByTag ${CpuProfilerController.userTagNone}',
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
                    : (String tag) => _onUserTagChanged(tag, context),
              ),
            );
          },
        );
      },
    );
  }

  DropdownMenuItem _buildMenuItem({
    @required String display,
    @required String value,
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
      Notifications.of(context).push(e.toString());
    }
  }
}
