// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/charts/flame_chart.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/feature_flags.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/theme.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/tab.dart';
import '../../shared/utils.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_model.dart';
import 'panes/bottom_up.dart';
import 'panes/call_tree.dart';
import 'panes/cpu_flame_chart.dart';
import 'panes/method_table.dart';

// TODO(kenz): provide useful UI upon selecting a CPU stack frame.

class CpuProfiler extends StatefulWidget {
  CpuProfiler({
    required this.data,
    required this.controller,
    this.searchFieldKey,
    this.standaloneProfiler = true,
    this.summaryView,
  })  : callTreeRoots = data.callTreeRoots,
        bottomUpRoots = data.bottomUpRoots,
        tabs = [
          if (summaryView != null)
            _buildTab(key: summaryTab, tabName: 'Summary'),
          _buildTab(key: bottomUpTab, tabName: 'Bottom Up'),
          _buildTab(key: callTreeTab, tabName: 'Call Tree'),
          if (FeatureFlags.methodTable)
            _buildTab(key: methodTableTab, tabName: 'Method Table'),
          _buildTab(key: flameChartTab, tabName: 'CPU Flame Chart'),
        ];

  static DevToolsTab _buildTab({Key? key, required String tabName}) {
    return DevToolsTab.create(
      key: key,
      tabName: tabName,
      gaPrefix: 'cpuProfilerTab',
    );
  }

  final CpuProfileData data;

  final CpuProfilerController controller;

  final List<CpuStackFrame> callTreeRoots;

  final List<CpuStackFrame> bottomUpRoots;

  final GlobalKey? searchFieldKey;

  final bool standaloneProfiler;

  final Widget? summaryView;

  final List<DevToolsTab> tabs;

  static const Key dataProcessingKey = Key('CpuProfiler - data is processing');

  // When content of the selected DevToolsTab from the tab controller has any
  // of these three keys, we will not show the expand/collapse buttons.
  static const Key flameChartTab = Key('cpu profile flame chart tab');
  static const Key methodTableTab = Key('cpu profile method table tab');
  static const Key summaryTab = Key('cpu profile summary tab');

  static const Key bottomUpTab = Key('cpu profile bottom up tab');
  static const Key callTreeTab = Key('cpu profile call tree tab');

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
  bool _tabControllerInitialized = false;

  late TabController _tabController;

  late CpuProfileData data;

  @override
  void initState() {
    super.initState();
    data = widget.data;
    _initTabController();
  }

  @override
  void didUpdateWidget(CpuProfiler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _initTabController();
    }
    if (widget.data != oldWidget.data) {
      data = widget.data;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _initTabController() {
    if (_tabControllerInitialized) {
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
    }
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    );
    _tabControllerInitialized = true;

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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final currentTab = widget.tabs[_tabController.index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AreaPaneHeader(
          needsTopBorder: false,
          leftPadding: 0,
          tall: true,
          title: TabBar(
            labelColor:
                textTheme.bodyLarge?.color ?? colorScheme.defaultForeground,
            isScrollable: true,
            controller: _tabController,
            tabs: widget.tabs,
          ),
          actions: [
            if (currentTab.key != CpuProfiler.summaryTab) ...[
              FilterButton(
                onPressed: _showFilterDialog,
                isFilterActive: widget.controller.isFilterActive,
              ),
              const SizedBox(width: denseSpacing),
              if (currentTab.key != CpuProfiler.flameChartTab &&
                  currentTab.key != CpuProfiler.methodTableTab) ...[
                const DisplayTreeGuidelinesToggle(),
                const SizedBox(width: denseSpacing),
              ],
              UserTagDropdown(widget.controller),
              const SizedBox(width: denseSpacing),
              ValueListenableBuilder<bool>(
                valueListenable: preferences.vmDeveloperModeEnabled,
                builder: (context, vmDeveloperModeEnabled, _) {
                  if (!vmDeveloperModeEnabled) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: denseSpacing),
                    child: ModeDropdown(widget.controller),
                  );
                },
              ),
            ],
            // TODO(kenz): support search for call tree and bottom up tabs as
            // well. This will require implementing search for tree tables.
            if (currentTab.key == CpuProfiler.flameChartTab) ...[
              if (widget.searchFieldKey != null) _buildSearchField(),
              FlameChartHelpButton(
                gaScreen: widget.standaloneProfiler
                    ? gac.cpuProfiler
                    : gac.performance,
                gaSelection: gac.cpuProfileFlameChartHelp,
                additionalInfo: [
                  ...dialogSubHeader(Theme.of(context), 'Legend'),
                  Legend(
                    entries: [
                      LegendEntry(
                        'App code (code from your app and imported packages)',
                        appCodeColor.background.colorFor(colorScheme),
                      ),
                      LegendEntry(
                        'Native code (code from the native runtime - Android, iOS, etc.)',
                        nativeCodeColor.background.colorFor(colorScheme),
                      ),
                      LegendEntry(
                        'Dart core libraries (code from the Dart SDK)',
                        dartCoreColor.background.colorFor(colorScheme),
                      ),
                      LegendEntry(
                        'Flutter Framework (code from the Flutter SDK)',
                        flutterCoreColor.background.colorFor(colorScheme),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (currentTab.key != CpuProfiler.flameChartTab &&
                currentTab.key != CpuProfiler.summaryTab &&
                currentTab.key != CpuProfiler.methodTableTab) ...[
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
            ],
          ],
        ),
        ValueListenableBuilder<CpuProfilerViewType>(
          valueListenable: widget.controller.viewType,
          builder: (context, viewType, _) {
            return Expanded(
              child: TabBarView(
                physics: defaultTabBarViewPhysics,
                controller: _tabController,
                children: _buildProfilerViews(),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showFilterDialog() {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => CpuProfileFilterDialog(
          controller: widget.controller,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: wideSearchTextWidth,
      height: defaultTextFieldHeight,
      child: buildSearchField(
        controller: widget.controller,
        searchFieldKey: widget.searchFieldKey!,
        searchFieldEnabled: true,
        shouldRequestFocus: false,
        supportsNavigation: true,
      ),
    );
  }

  List<Widget> _buildProfilerViews() {
    final bottomUp = KeepAliveWrapper(
      child: ValueListenableBuilder<bool>(
        valueListenable: preferences.cpuProfiler.displayTreeGuidelines,
        builder: (context, displayTreeGuidelines, _) {
          return CpuBottomUpTable(
            widget.bottomUpRoots,
            displayTreeGuidelines: displayTreeGuidelines,
          );
        },
      ),
    );
    final callTree = KeepAliveWrapper(
      child: ValueListenableBuilder<bool>(
        valueListenable: preferences.cpuProfiler.displayTreeGuidelines,
        builder: (context, displayTreeGuidelines, _) {
          return CpuCallTreeTable(
            widget.callTreeRoots,
            displayTreeGuidelines: displayTreeGuidelines,
          );
        },
      ),
    );
    const methodTable = KeepAliveWrapper(
      child: CpuMethodTable(),
    );
    final cpuFlameChart = KeepAliveWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CpuProfileFlameChart(
            data: data,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            selectionNotifier: widget.controller.selectedCpuStackFrameNotifier,
            searchMatchesNotifier: widget.controller.searchMatches,
            activeSearchMatchNotifier: widget.controller.activeSearchMatch,
            onDataSelected: (sf) => widget.controller.selectCpuStackFrame(sf),
          );
        },
      ),
    );
    final summaryView = widget.summaryView;
    // TODO(kenz): make this order configurable.
    return [
      if (summaryView != null) summaryView,
      bottomUp,
      callTree,
      if (FeatureFlags.methodTable) methodTable,
      cpuFlameChart,
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

class DisplayTreeGuidelinesToggle extends StatelessWidget {
  const DisplayTreeGuidelinesToggle();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: preferences.cpuProfiler.displayTreeGuidelines,
      builder: (context, displayTreeGuidelines, _) {
        return ToggleButton(
          onPressed: () {
            preferences.cpuProfiler.displayTreeGuidelines.value =
                !displayTreeGuidelines;
          },
          isSelected: displayTreeGuidelines,
          message: 'Display guidelines',
          icon: Icons.stacked_bar_chart,
        );
      },
    );
  }
}

class CpuProfileFilterDialog extends StatelessWidget {
  const CpuProfileFilterDialog({required this.controller, Key? key})
      : super(key: key);

  static const filterQueryInstructions = '''
Type a filter query to show or hide specific stack frames.

Any text that is not paired with an available filter key below will be queried against all categories (method, uri).

Available filters:
    'uri', 'u'       (e.g. 'uri:my_dart_package/some_lib.dart', '-u:some_lib_to_hide')

Example queries:
    'someMethodName uri:my_dart_package,b_dart_package'
    '.toString -uri:flutter'
''';

  double get _filterDialogWidth => scaleByFontFactor(400.0);

  final CpuProfilerController controller;

  @override
  Widget build(BuildContext context) {
    return FilterDialog<CpuStackFrame>(
      dialogWidth: _filterDialogWidth,
      controller: controller,
      queryInstructions: filterQueryInstructions,
    );
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
              onPressed: controller.enableCpuProfiler,
              child: const Text('Enable profiler'),
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
    return ValueListenableBuilder<String>(
      valueListenable: controller.userTagFilter,
      builder: (context, userTag, _) {
        final userTags = controller.userTags;
        final tooltip = userTags.isNotEmpty
            ? 'Filter the CPU profile by the given UserTag'
            : 'No UserTags found for this CPU profile';
        return SizedBox(
          height: defaultButtonHeight,
          child: DevToolsTooltip(
            message: tooltip,
            child: ValueListenableBuilder<bool>(
              valueListenable: preferences.vmDeveloperModeEnabled,
              builder: (context, vmDeveloperModeEnabled, _) {
                return RoundedDropDownButton<String>(
                  isDense: true,
                  style: Theme.of(context).textTheme.bodyMedium,
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
                        userTags.first == UserTag.defaultTag.label)) ...[
                      for (final tag in userTags)
                        _buildMenuItem(
                          display: '$filterByTag $tag',
                          value: tag,
                        ),
                      _buildMenuItem(
                        display: 'Group by: User Tag',
                        value: CpuProfilerController.groupByUserTag,
                      ),
                    ],
                    if (vmDeveloperModeEnabled)
                      _buildMenuItem(
                        display: 'Group by: VM Tag',
                        value: CpuProfilerController.groupByVmTag,
                      ),
                  ],
                  onChanged: userTags.isEmpty ||
                          (userTags.length == 1 &&
                              userTags.first == UserTag.defaultTag.label)
                      ? null
                      : (String? tag) => _onUserTagChanged(tag!),
                );
              },
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<String> _buildMenuItem({
    required String display,
    required String value,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: Text(display),
    );
  }

  void _onUserTagChanged(String newTag) async {
    try {
      await controller.loadDataWithTag(newTag);
    } catch (e) {
      notificationService.push(e.toString());
    }
  }
}

/// DropdownButton that controls the value of
/// [ProfilerScreenController.viewType].
class ModeDropdown extends StatelessWidget {
  const ModeDropdown(this.controller);

  final CpuProfilerController controller;

  @override
  Widget build(BuildContext context) {
    const mode = 'View:';
    return ValueListenableBuilder<CpuProfilerViewType>(
      valueListenable: controller.viewType,
      builder: (context, viewType, _) {
        final tooltip = viewType == CpuProfilerViewType.function
            ? 'Display the profile in terms of the Dart call stack '
                '(i.e., inlined frames are expanded)'
            : 'Display the profile in terms of native stack frames '
                '(i.e., inlined frames are not expanded, display code objects '
                'rather than individual functions)';
        return SizedBox(
          height: defaultButtonHeight,
          child: DevToolsTooltip(
            message: tooltip,
            child: RoundedDropDownButton<CpuProfilerViewType>(
              isDense: true,
              style: Theme.of(context).textTheme.bodyMedium,
              value: viewType,
              items: [
                _buildMenuItem(
                  display: '$mode ${CpuProfilerViewType.function}',
                  value: CpuProfilerViewType.function,
                ),
                _buildMenuItem(
                  display: '$mode ${CpuProfilerViewType.code}',
                  value: CpuProfilerViewType.code,
                ),
              ],
              onChanged: (type) => controller.updateView(type!),
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<CpuProfilerViewType> _buildMenuItem({
    required String display,
    required CpuProfilerViewType value,
  }) {
    return DropdownMenuItem<CpuProfilerViewType>(
      value: value,
      child: Text(display),
    );
  }
}
