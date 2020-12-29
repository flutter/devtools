// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../auto_dispose_mixin.dart';
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
  })  : callTreeRoots = data != null ? [data.cpuProfileRoot.deepCopy()] : [],
        bottomUpRoots = data != null
            ? BottomUpProfileTransformer.processData(data.cpuProfileRoot)
            : [];

  final CpuProfileData data;

  final CpuProfilerController controller;

  final List<CpuStackFrame> callTreeRoots;

  final List<CpuStackFrame> bottomUpRoots;

  final Key searchFieldKey;

  static const Key expandButtonKey = Key('CpuProfiler - Expand Button');
  static const Key collapseButtonKey = Key('CpuProfiler - Collapse Button');
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
    with SingleTickerProviderStateMixin, AutoDisposeMixin, SearchFieldMixin {
  TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController =
        TabController(length: CpuProfiler.tabs.length, vsync: this);
    addAutoDisposeListener(_tabController);
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
            widget.data != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TabBar(
              labelColor: textTheme.bodyText1.color,
              isScrollable: true,
              controller: _tabController,
              tabs: CpuProfiler.tabs,
            ),
            // TODO(kenz): support search for call tree and bottom up tabs as
            // well. This will require implementing search for tree tables.
            if (currentTab.key == CpuProfiler.flameChartTab &&
                widget.searchFieldKey != null)
              Container(
                width: wideSearchTextWidth,
                height: defaultTextFieldHeight,
                child: buildSearchField(
                  controller: widget.controller,
                  searchFieldKey: widget.searchFieldKey,
                  searchFieldEnabled: hasData,
                  shouldRequestFocus: false,
                  supportsNavigation: true,
                ),
              ),
            if (currentTab.key != CpuProfiler.flameChartTab)
              Row(children: [
                _expandAllButton(currentTab),
                _collapseAllButton(currentTab),
              ]),
          ],
        ),
        Expanded(
          child: _buildCpuProfileDataView(),
        ),
      ],
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
        style: Theme.of(context).textTheme.subtitle1,
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
          onSelected: (sf) => widget.controller.selectCpuStackFrame(sf),
        );
      },
    );
    // TODO(kenz): make this order configurable.
    return [bottomUp, callTree, cpuFlameChart];
  }

  Widget _expandAllButton(Tab currentTab) {
    return OutlineButton(
      key: CpuProfiler.expandButtonKey,
      onPressed: () {
        _performOnDataRoots((root) => root.expandCascading(), currentTab);
      },
      child: const Text('Expand All'),
    );
  }

  Widget _collapseAllButton(Tab currentTab) {
    return OutlineButton(
      key: CpuProfiler.collapseButtonKey,
      onPressed: () {
        _performOnDataRoots((root) => root.collapseCascading(), currentTab);
      },
      child: const Text('Collapse All'),
    );
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
            child: RaisedButton(
              child: const Text('Enable profiler'),
              onPressed: controller.enableCpuProfiler,
            ),
          ),
        ],
      ),
    );
  }
}
