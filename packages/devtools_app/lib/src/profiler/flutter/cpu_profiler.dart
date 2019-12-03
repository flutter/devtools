// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../../ui/fake_flutter/_real_flutter.dart';
import '../cpu_profile_model.dart';
import 'cpu_profile_flame_chart.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatelessWidget {
  const CpuProfiler({
    @required this.data,
    @required this.selectedStackFrame,
    @required this.onStackFrameSelected,
  });

  final CpuProfileData data;

  final CpuStackFrame selectedStackFrame;

  final Function(CpuStackFrame stackFrame) onStackFrameSelected;

  // TODO(kenz): the summary tab should be available for UI events in the
  // timeline.
  static const cpuProfilerTabs = [
    Tab(text: 'CPU Flame Chart'),
    Tab(text: 'Call Tree'),
    Tab(text: 'Bottom Up'),
  ];

  static const emptyCpuProfile = 'No CPU profile data';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DefaultTabController(
      length: cpuProfilerTabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TabBar(
            labelColor: Theme.of(context).textTheme.body1.color,
            isScrollable: true,
            tabs: cpuProfilerTabs,
          ),
          Expanded(
            child: _buildCpuProfileDataView(textTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildCpuProfileDataView(TextTheme textTheme) {
    if (data != null) {
      return data.isEmpty
          ? _buildEmptyDataView(textTheme)
          : TabBarView(
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
        emptyCpuProfile,
        style: textTheme.subhead,
      ),
    );
  }

  // TODO(kenz): implement call tree and bottom up.
  List<Widget> _buildProfilerViews() {
    final cpuFlameChart = LayoutBuilder(builder: (context, constraints) {
      return CpuProfileFlameChart(
        data,
        // TODO(kenz): remove * 2 once zooming is possible. This is so that we can
        // test horizontal scrolling functionality.
        width: constraints.maxWidth * 2,
        selected: selectedStackFrame,
        onSelected: (sf) => onStackFrameSelected(sf),
      );
    });

    // TODO(kenz): tree table is extremely slow with large data set. It should
    // be optimized before including in the profiler.
    //    final callTree = CpuCallTreeTable(data);
    const callTree = Center(
      child: Text(
        'TODO CPU call tree',
      ),
    );
    const bottomUp = Center(
      child: Text(
        'TODO CPU bottom up',
      ),
    );
    return [cpuFlameChart, callTree, bottomUp];
  }
}
