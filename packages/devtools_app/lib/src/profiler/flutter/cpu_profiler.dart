// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../../ui/fake_flutter/_real_flutter.dart';

class CpuProfilerView extends StatelessWidget {
  // TODO(kenz): the summary tab should be available for UI events in the
  // timeline.
  static const cpuProfilerTabs = [
    Tab(text: 'CPU Flame Chart'),
    Tab(text: 'Call Tree'),
    Tab(text: 'Bottom Up'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: cpuProfilerTabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const TabBar(
            isScrollable: true,
            tabs: cpuProfilerTabs,
          ),
          Expanded(
            child: TabBarView(
              children: _buildProfilerViews(),
            ),
          )
        ],
      ),
    );
  }

  // TODO(kenz): implement all of these views.
  List<Widget> _buildProfilerViews() {
    const cpuFlameChart = Center(
      child: Text(
        'TODO CPU flame chart',
      ),
    );
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
