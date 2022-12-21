// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/ui/tab.dart';
import 'memory_controller.dart';
import 'panes/allocation_profile/allocation_profile_table_view.dart';
import 'panes/allocation_tracing/allocation_profile_tracing_view.dart';
import 'panes/diff/diff_pane.dart';
import 'panes/leaks/leaks_pane.dart';

@visibleForTesting
class MemoryScreenKeys {
  static const leaksTab = Key('Leaks Tab');
  static const dartHeapTableProfileTab = Key('Dart Heap Profile Tab');
  static const dartHeapAllocationTracingTab =
      Key('Dart Heap Allocation Tracing Tab');
  static const diffTab = Key('Diff Tab');
}

class MemoryTabView extends StatelessWidget {
  const MemoryTabView(
    this.controller,
  );

  static const _gaPrefix = 'memoryTab';

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.shouldShowLeaksTab,
      builder: (context, showLeaksTab, _) {
        final tabRecords = _generateTabRecords();
        final tabs = <DevToolsTab>[];
        final tabViews = <Widget>[];
        for (final record in tabRecords) {
          tabs.add(record.tab);
          tabViews.add(record.tabView);
        }
        return AnalyticsTabbedView(
          tabs: tabs,
          tabViews: tabViews,
          initialSelectedIndex: controller.selectedFeatureTabIndex,
          gaScreen: gac.memory,
          onTabChanged: (int index) {
            controller.selectedFeatureTabIndex = index;
          },
        );
      },
    );
  }

  List<TabRecord> _generateTabRecords() {
    return [
      TabRecord(
        tab: DevToolsTab.create(
          key: MemoryScreenKeys.dartHeapTableProfileTab,
          tabName: 'Profile',
          gaPrefix: _gaPrefix,
        ),
        tabView: KeepAliveWrapper(
          child: AllocationProfileTableView(
            controller: controller.allocationProfileController,
          ),
        ),
      ),
      TabRecord(
        tab: DevToolsTab.create(
          key: MemoryScreenKeys.diffTab,
          gaPrefix: _gaPrefix,
          tabName: 'Diff',
        ),
        tabView: KeepAliveWrapper(
          child: DiffPane(
            diffController: controller.diffPaneController,
          ),
        ),
      ),
      TabRecord(
        tab: DevToolsTab.create(
          key: MemoryScreenKeys.dartHeapAllocationTracingTab,
          tabName: 'Trace',
          gaPrefix: _gaPrefix,
        ),
        tabView: const KeepAliveWrapper(
          child: AllocationProfileTracingView(),
        ),
      ),
      if (controller.shouldShowLeaksTab.value)
        TabRecord(
          tab: DevToolsTab.create(
            key: MemoryScreenKeys.leaksTab,
            gaPrefix: _gaPrefix,
            tabName: 'Detect Leaks',
          ),
          tabView: const KeepAliveWrapper(child: LeaksPane()),
        ),
    ];
  }
}
