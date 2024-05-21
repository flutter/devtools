// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/common_widgets.dart';
import '../../../shared/primitives/simple_items.dart';
import '../../../shared/ui/tab.dart';
import '../panes/diff/diff_pane.dart';
import '../panes/profile/profile_view.dart';
import '../panes/tracing/tracing_view.dart';
import 'memory_controller.dart';

@visibleForTesting
class MemoryScreenKeys {
  static const dartHeapTableProfileTab = Key('Dart Heap Profile Tab');
  static const dartHeapAllocationTracingTab =
      Key('Dart Heap Allocation Tracing Tab');
  static const diffTab = Key('Diff Tab');
}

class MemoryTabView extends StatelessWidget {
  const MemoryTabView(
    this.controller, {
    super.key,
  });

  static const _gaPrefix = 'memoryTab';

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return AnalyticsTabbedView(
      tabs: _generateTabRecords(),
      initialSelectedIndex: controller.selectedFeatureTabIndex,
      gaScreen: gac.memory,
      onTabChanged: (int index) {
        controller.selectedFeatureTabIndex = index;
      },
    );
  }

  TabAndView _diff() => (
        tab: DevToolsTab.create(
          key: MemoryScreenKeys.diffTab,
          gaPrefix: _gaPrefix,
          tabName: 'Diff Snapshots',
        ),
        tabView: KeepAliveWrapper(
          child: DiffPane(
            diffController: controller.diff,
          ),
        ),
      );

  TabAndView _profile() => (
        tab: DevToolsTab.create(
          key: MemoryScreenKeys.dartHeapTableProfileTab,
          tabName: 'Profile Memory',
          gaPrefix: _gaPrefix,
        ),
        tabView: KeepAliveWrapper(
          child: AllocationProfileTableView(
            controller: controller.profile!,
          ),
        ),
      );

  TabAndView _trace() => (
        tab: DevToolsTab.create(
          key: MemoryScreenKeys.dartHeapAllocationTracingTab,
          tabName: 'Trace Instances',
          gaPrefix: _gaPrefix,
        ),
        tabView: KeepAliveWrapper(
          child: TracingPane(controller: controller.tracing!),
        ),
      );

  List<TabAndView> _generateTabRecords() {
    final hasData = controller.mode != ControllerCreationMode.disconnected;
    return [
      if (hasData) _profile(),
      // Diff is enabled even in disconnected mode to allow users to load
      // snapshots from file.
      _diff(),
      if (hasData) _trace(),
    ];
  }
}
