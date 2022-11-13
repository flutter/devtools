// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/search.dart';
import '../../ui/tab.dart';
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

class MemoryTabs extends StatefulWidget {
  const MemoryTabs(
    this.controller,
  );

  final MemoryController controller;

  @override
  _MemoryTabsState createState() => _MemoryTabsState();
}

class _MemoryTabsState extends State<MemoryTabs>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryTabs>,
        SearchFieldMixin<MemoryTabs>,
        TickerProviderStateMixin {
  static const _gaPrefix = 'memoryTab';

  late List<Tab> _tabs;
  late TabController _tabController;
  final ValueNotifier<int> _currentTab = ValueNotifier(0);

  void _initTabs() {
    _tabs = [
      DevToolsTab.create(
        key: MemoryScreenKeys.dartHeapTableProfileTab,
        tabName: 'Profile',
        gaPrefix: _gaPrefix,
      ),
      DevToolsTab.create(
        key: MemoryScreenKeys.dartHeapAllocationTracingTab,
        tabName: 'Allocation Tracing',
        gaPrefix: _gaPrefix,
      ),
      DevToolsTab.create(
        key: MemoryScreenKeys.diffTab,
        gaPrefix: _gaPrefix,
        tabName: 'Diff',
      ),
      if (widget.controller.shouldShowLeaksTab.value)
        DevToolsTab.create(
          key: MemoryScreenKeys.leaksTab,
          gaPrefix: _gaPrefix,
          tabName: 'Leaks',
        ),
    ];

    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() => _currentTab.value = _tabController.index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    _initTabs();

    addAutoDisposeListener(controller.shouldShowLeaksTab, () {
      setState(() {
        _initTabs();
      });
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: defaultSpacing),
        ValueListenableBuilder<int>(
          valueListenable: _currentTab,
          builder: (context, index, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabBar(
                labelColor: themeData.textTheme.bodyLarge!.color,
                isScrollable: true,
                controller: _tabController,
                tabs: _tabs,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            controller: _tabController,
            children: [
              // Profile Tab
              KeepAliveWrapper(
                child: AllocationProfileTableView(
                  controller: controller.allocationProfileController,
                ),
              ),
              const KeepAliveWrapper(
                child: AllocationProfileTracingView(),
              ),
              // Diff tab.
              KeepAliveWrapper(
                child: DiffPane(
                  diffController: controller.diffPaneController,
                ),
              ),
              // Leaks tab.
              if (controller.shouldShowLeaksTab.value)
                const KeepAliveWrapper(child: LeaksPane()),
            ],
          ),
        ),
      ],
    );
  }

  Widget tableExample(IconData? iconData, String entry) {
    final themeData = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconData == null
            ? Text(' ', style: themeData.fixedFontStyle)
            : Icon(iconData),
        Text(entry, style: themeData.fixedFontStyle),
      ],
    );
  }
}
