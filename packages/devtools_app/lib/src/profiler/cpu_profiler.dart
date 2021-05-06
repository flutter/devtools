// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:developer';

import 'package:flutter/material.dart';

import '../auto_dispose_mixin.dart';
import '../charts/flame_chart.dart';
import '../common_widgets.dart';
import '../notifications.dart';
import '../theme.dart';
import '../ui/search.dart';
import 'cpu_profile_bottom_up.dart';
import 'cpu_profile_call_tree.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_flame_chart.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_transformer.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  CpuProfiler({
    @required this.data,
    @required this.controller,
    this.searchFieldKey,
    this.standaloneProfiler = true,
  })  : callTreeRoots = data != null ? [data.cpuProfileRoot.deepCopy()] : [],
        bottomUpRoots = data != null
            ? BottomUpProfileTransformer.processData(data.cpuProfileRoot)
            : [];

  final CpuProfileData data;

  final CpuProfilerController controller;

  final List<CpuStackFrame> callTreeRoots;

  final List<CpuStackFrame> bottomUpRoots;

  final Key searchFieldKey;

  final bool standaloneProfiler;

  static const Key dataProcessingKey = Key('CpuProfiler - data is processing');

  // When content of the selected tab from thee tab controller has this key,
  // we will not show the expand/collapse buttons.
  static const Key flameChartTab = Key('cpu profile flame chart tab');
  static const Key callTreeTab = Key('cpu profile call tree tab');
  static const Key bottomUpTab = Key('cpu profile bottom up tab');

  // TODO(kenz): the summary tab should be available for UI events in the
  // timeline.
  static const tabs = [
    Tab(key: bottomUpTab, text: 'Bottom Up'),
    Tab(key: callTreeTab, text: 'Call Tree'),
    Tab(key: flameChartTab, text: 'CPU Flame Chart'),
  ];

  static const emptyCpuProfile = 'No CPU profile data';

  @override
  _CpuProfilerState createState() => _CpuProfilerState();
}

// TODO(kenz): preserve tab controller index when updating CpuProfiler with new
// data. The state is being destroyed with every new cpu profile - investigate.
class _CpuProfilerState extends State<CpuProfiler>
    with
        SingleTickerProviderStateMixin,
        AutoDisposeMixin,
        SearchFieldMixin<CpuProfiler> {
  TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: CpuProfiler.tabs.length,
      vsync: this,
    )..index = widget.controller.selectedProfilerTabIndex;
    addAutoDisposeListener(_tabController, () {
      setState(() {
        widget.controller.changeSelectedProfilerTab(_tabController.index);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentTab = CpuProfiler.tabs[_tabController.index];
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
                tabs: CpuProfiler.tabs,
              ),
              const Spacer(),
              if (hasData) ...[
                UserTagDropdown(widget.controller),
                const SizedBox(width: defaultSpacing),
                // TODO(kenz): support search for call tree and bottom up tabs as
                // well. This will require implementing search for tree tables.
                if (currentTab.key == CpuProfiler.flameChartTab)
                  Row(
                    children: [
                      if (widget.searchFieldKey != null)
                        _buildSearchField(hasData),
                      FlameChartHelpButton(),
                    ],
                  ),
                if (currentTab.key != CpuProfiler.flameChartTab)
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
      return widget.data.isEmpty
          ? _buildEmptyDataView()
          : TabBarView(
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

  Widget _buildEmptyDataView() {
    return Center(
      child: Text(
        CpuProfiler.emptyCpuProfile,
        style: Theme.of(context).subtleTextStyle,
      ),
    );
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
    return [bottomUp, callTree, cpuFlameChart];
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
                onChanged: userTags.isNotEmpty
                    ? (String tag) => _onUserTagChanged(tag, context)
                    : null,
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
