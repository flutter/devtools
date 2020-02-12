// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../../ui/fake_flutter/_real_flutter.dart';
import '../cpu_profile_model.dart';
import '../cpu_profiler_controller.dart';
import 'cpu_profile_call_tree.dart';
import 'cpu_profile_flame_chart.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  const CpuProfiler({@required this.data, @required this.controller});

  final CpuProfileData data;

  final CpuProfilerController controller;

  static const Key expandButtonKey = Key('CpuProfiler - Expand Button');
  static const Key collapseButtonKey = Key('CpuProfiler - Collapse Button');
  static const Key dataProcessingKey = Key('CpuProfiler - data is processing');

  // When content of the selected tab from thee tab controller has this key,
  // we will not show the expand/collapse buttons.
  static const Key _hideExpansionButtons = Key('hide expansion buttons');

  // TODO(kenz): the summary tab should be available for UI events in the
  // timeline.
  static const tabs = [
    Tab(key: _hideExpansionButtons, text: 'CPU Flame Chart'),
    Tab(text: 'Call Tree'),
    Tab(text: 'Bottom Up'),
  ];

  static const emptyCpuProfile = 'No CPU profile data';

  @override
  _CpuProfilerState createState() => _CpuProfilerState();
}

class _CpuProfilerState extends State<CpuProfiler>
    with SingleTickerProviderStateMixin {
  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: CpuProfiler.tabs.length, vsync: this)
      ..addListener(() {
        setState(() {});
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
            if (currentTab.key != CpuProfiler._hideExpansionButtons)
              Row(children: [
                OutlineButton(
                  key: CpuProfiler.expandButtonKey,
                  onPressed: () {
                    setState(widget.data.cpuProfileRoot.expandCascading);
                  },
                  child: const Text('Expand All'),
                ),
                OutlineButton(
                  key: CpuProfiler.collapseButtonKey,
                  onPressed: () {
                    setState(widget.data.cpuProfileRoot.collapseCascading);
                  },
                  child: const Text('Collapse All'),
                ),
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
              physics: const NeverScrollableScrollPhysics(),
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

  // TODO(kenz): implement call tree and bottom up.
  List<Widget> _buildProfilerViews() {
    final cpuFlameChart = LayoutBuilder(
      builder: (context, constraints) {
        return ValueListenableBuilder<CpuStackFrame>(
          valueListenable: widget.controller.selectedCpuStackFrameNotifier,
          builder: (context, selectedStackFrame, _) {
            return CpuProfileFlameChart(
              widget.data,
              width: constraints.maxWidth,
              selected: selectedStackFrame,
              onSelected: (sf) => widget.controller.selectCpuStackFrame(sf),
            );
          },
        );
      },
    );

    final callTree = CpuCallTreeTable(widget.data);

    const bottomUp = Center(
      child: Text(
        'TODO CPU bottom up',
      ),
    );
    return [cpuFlameChart, callTree, bottomUp];
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
