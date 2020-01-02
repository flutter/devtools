// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../../ui/fake_flutter/_real_flutter.dart';
import '../cpu_profile_model.dart';
import 'cpu_profile_call_tree.dart';
import 'cpu_profile_flame_chart.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  const CpuProfiler({
    @required this.data,
    @required this.selectedStackFrame,
    @required this.onStackFrameSelected,
  });

  final CpuProfileData data;

  final CpuStackFrame selectedStackFrame;

  final Function(CpuStackFrame stackFrame) onStackFrameSelected;

  static const Key expandButtonKey = Key('CpuProfiler - Expand Button');
  static const Key collapseButtonKey = Key('CpuProfiler - Collapse Button');

  // TODO(kenz): the summary tab should be available for UI events in the
  // timeline.
  static const tabs = [
    Tab(text: 'CPU Flame Chart'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TabBar(
              labelColor: Theme.of(context).textTheme.body1.color,
              isScrollable: true,
              controller: _tabController,
              tabs: CpuProfiler.tabs,
            ),
            if (_tabController.index != 0)
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
          child: _buildCpuProfileDataView(textTheme),
        ),
      ],
    );
  }

  Widget _buildCpuProfileDataView(TextTheme textTheme) {
    if (widget.data != null) {
      return widget.data.isEmpty
          ? _buildEmptyDataView(textTheme)
          : TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: _buildProfilerViews(),
            );
    } else {
      // If [data] is null, we can assume that CPU profile data is being fetched
      // and processed.
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildEmptyDataView(TextTheme textTheme) {
    return Center(
      child: Text(
        CpuProfiler.emptyCpuProfile,
        style: textTheme.subhead,
      ),
    );
  }

  // TODO(kenz): implement call tree and bottom up.
  List<Widget> _buildProfilerViews() {
    final cpuFlameChart = LayoutBuilder(builder: (context, constraints) {
      return CpuProfileFlameChart(
        widget.data,
        // TODO(kenz): remove * 2 once zooming is possible. This is so that we can
        // test horizontal scrolling functionality.
        width: constraints.maxWidth * 2,
        selected: widget.selectedStackFrame,
        onSelected: (sf) => widget.onStackFrameSelected(sf),
      );
    });

    final callTree = CpuCallTreeTable(widget.data);

    const bottomUp = Center(
      child: Text(
        'TODO CPU bottom up',
      ),
    );
    return [cpuFlameChart, callTree, bottomUp];
  }
}
